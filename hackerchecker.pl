#!/usr/bin/perl

use strict;
use Mojolicious::Lite -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Mojo::Util qw(url_escape);
#use Data::Dumper;


my $checker;

get '/check_detail' => sub {
	my $self = shift;
	my $server = $self->param('server');
	
	if ($server){
		$self->app->log->info("server=$server");

		my $url = 'https://api.gametools.network/bfv/players/?name='.$server; 
		
		$self->render_later;
		$self->ua->get($url => sub {
			my ($ua, $tx) = @_;
			#$self->render_dumper('test');
			
			
			my $player_list = decode_json($tx->res->body);

			my @user_id_list;
			
			foreach my $team (@{$player_list->{teams}}){
				foreach my $p (@{$team->{players}}){
					push @user_id_list, $p->{user_id};
				}
			}
			if (scalar @user_id_list){
				$url = 'https://api.gametools.network/bfban/checkban?userids='; 
				my $ids = join ('%2C', @user_id_list);
				$url .= $ids;
				my $tx_ban = $self->ua->get($url);
				if ($tx_ban->res->code == 200){
					my $banned = decode_json($tx_ban->res->body);
					
					foreach my $team (@{$player_list->{teams}}){
						foreach my $p (@{$team->{players}}){
							my $uid = $p->{user_id};
							$p->{hacker} = $banned->{userids}->{$uid}->{hacker};
						}
					}
				}	
			} 
			
			$self->render(json => $player_list, status => $tx->res->code);
			
		});
		Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
#		return($self->render(json => $json, status=>$ua->get($url)->result->code));
	}
	else {
		return $self->render(
			json => { error => 'no server provided' },
			status => 401
		);
	}
	
};


get '/check' => sub {
	my $self = shift;
	my $server = $self->param('server');
	
	my $resp;
	
	if ($server){
		$self->app->log->info("server=$server");

		my $url = 'https://api.gametools.network/bfv/players/?name='.$server; 
		
		
		$self->ua->get($url => sub {
			my ($ua, $tx) = @_;
			#$self->render_dumper('test');
			
			
			my $player_list = decode_json($tx->res->body);

			my @user_id_list;
			$self->render_later;

			$resp->{server}->{name} = $player_list->{serverinfo}->{name};
			$resp->{server}->{map} = $player_list->{serverinfo}->{level};
			foreach my $team (@{$player_list->{teams}}){
				foreach my $p (@{$team->{players}}){
					push @user_id_list, $p->{user_id};
				}				
			}
			if (scalar @user_id_list){
				$url = 'https://api.gametools.network/bfban/checkban?userids='; 
				my $ids = join ('%2C', @user_id_list);
				$url .= $ids;
				my $tx_ban = $self->ua->get($url);
				if ($tx_ban->res->code == 200){
					my $banned = decode_json($tx_ban->res->body);
					
					foreach my $team (@{$player_list->{teams}}){
						my $t = $team->{teamid};
						$resp->{team}->{$t}->{name} = $team->{name};
						foreach my $p (@{$team->{players}}){
							my $uid = $p->{user_id};
							$p->{hacker} = $banned->{userids}->{$uid}->{hacker};
							if ($banned->{userids}->{$uid}->{hacker} eq "true"){
								$resp->{team}->{$t}->{player}->{$p->{name}} = 'hacker';
							}
						}
					}
				}	
			} 
			
			$self->render(json => $resp, status => $tx->res->code);
			
		});
		Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
#		return($self->render(json => $json, status=>$ua->get($url)->result->code));
	}
	else {
		return $self->render(
			json => { error => 'no server provided' },
			status => 401
		);
	}
	
};



websocket '/data' => sub{
	my $self = shift;
	my $r_ip = $self->tx->remote_address;	
	my $forwarded_ip = $self->req->headers->header('X-Forwarded-For');
	my $r_port = $self->tx->remote_port;
	
	my $proxy = '';
	$proxy = '(behind proxy)' if $forwarded_ip;
	
	
	$r_ip = $forwarded_ip if $forwarded_ip;
	
	$self->app->log->info("[$r_ip:$r_port]$proxy Websocket opened");
	$self->inactivity_timeout(300);
	
	my $id = Mojo::IOLoop->recurring(30 => sub{
		return unless $self;
		return unless $self->{bfvserver};
		return unless $self->{bfvserver}->{start};
		if (exists($self->{bfvserver}->{start}) && $self->{bfvserver}->{start} eq "true"){			
			if ($self->{bfvserver}->{name}){
				$self->app->log->info("[$r_ip:$r_port] server='".$self->{bfvserver}->{name}."'");
				get_data($self);
			}
			else{
				$self->{bfvserver}->{start} = undef;				
			}
		}
	});
	
	$self->on(message => sub {
		my ($self, $message) = @_;
		
		my $json = decode_json($message);		
		$self->app->log->info("[$r_ip:$r_port] Rx: msg=".$message);
		if ($json && defined ($json->{server})){
			$self->{bfvserver}->{name} = $json->{server};
			$self->{bfvserver}->{start} = "true";
			get_data($self);
		};
	});
	$self->on(finish => sub{
		my ($self, $code, $reason) = @_;
		$self->app->log->debug("[$r_ip:$r_port] WebSocket closed with status $code") unless $code == 1006;
		$self->{bfvserver}->{start} = undef;
	});
};
 
any '/' => sub{
	my $self = shift;

	my $r_ip = $self->tx->remote_address;	
	my $forwarded_ip = $self->req->headers->header('X-Forwarded-For');
	
	my $proxy = '';
	my $url_data = $self->url_for('data')->to_abs;
	my $url_util = $self->url_for('util.js')->to_abs;	
	
	$proxy = '(behind proxy)' if $forwarded_ip;
	if ($proxy){
		$url_data = "ws://hackerchecker.mooo.com/hackerchecker/data";
		$url_util = "http://hackerchecker.mooo.com/hackerchecker/util.js";
	}
	$self->render(template => 'index', url_data => $url_data, url_util => $url_util);
};

any '*' => sub{
	my $self = shift;
	$self->render(
		json => { error => "invalid request."},
		status => 400
	);
};


#my $cleanup = Mojo::IOLoop->recurring(30 => clean_up);

app->secrets(['Eizbd{sds}','hs2l3o999skjdfew','3283nsdnn34']);

#app->start('daemon', '-m', 'development', '-l', 'http://*:3000');
app->start('daemon', '-m', 'production', '-l', 'http://*:3000');


# remove internal tree for server if data is too old
sub clean_up {
	foreach my $s (keys %{$checker}){
		my $age = time() - $checker->{$s}->{update_timestamp};		
		if ($age > 300){
			app->log->info("cleaning up $s");
			delete $checker->{$s};
			return;
		}
	}
}


sub get_data{
	my $self  = shift;
	my $server = url_escape($self->{bfvserver}->{name});
	my $url = 'https://api.gametools.network/bfv/players/?name='.$server;

	if ($self->{bfvserver}->{name} && defined $self->{bfvserver}->{name}){
		# check if we have data already.		
		foreach my $s (keys %{$checker}){
			#$self->app->log->info($s);
			my $serv = $self->{bfvserver}->{name};			
			if ($s =~ /\Q$serv/){			# \Q escape special chars from $serv 
				# found server
				# check age
				my $age = time() - $checker->{$s}->{update_timestamp};				
				$self->app->log->info("$s found (".$self->{bfvserver}->{name}.") age = $age");
				if ($age < 30){ # send internal data if we have it updated
					$self->send(encode_json($checker->{$s}));
					return;
				}
			}
		}		
	}
	
	# async get call
	$self->ua->get($url => sub {
		my ($ua, $tx) = @_;
		
		
		my $player_list = decode_json($tx->res->body);

		# save to internal tree. the key is the server name
		if (defined $player_list->{serverinfo}->{name}){
			$checker->{$player_list->{serverinfo}->{name}} = $player_list;			
		}
		my @user_id_list;
		
		foreach my $team (@{$player_list->{teams}}){
			foreach my $p (@{$team->{players}}){
				push @user_id_list, $p->{user_id};
			}
		}
		if (scalar @user_id_list){
			$url = 'https://api.gametools.network/bfban/checkban?userids='; 
			my $ids = join ('%2C', @user_id_list);
			$url .= $ids;
			my $tx_ban = $self->ua->get($url);
			if ($tx_ban->res->code == 200){
				my $banned = decode_json($tx_ban->res->body);
				
				foreach my $team (@{$player_list->{teams}}){
					foreach my $p (@{$team->{players}}){
						my $uid = $p->{user_id};
						$p->{hacker} = $banned->{userids}->{$uid}->{hacker};
					}
				}
			}	
		} 
		
		$self->send(encode_json($player_list));
		
	});		
}


__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="en">
<head>
<title>Hacker Checker</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-KK94CHFLLe+nY2dmCWGMq91rCGa5gtU4mk92HdvYe+M/SXH301p5ILy+dN9+nJOZ" crossorigin="anonymous">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/js/bootstrap.bundle.min.js" integrity="sha384-ENjdO4Dr2bkBIFxQpeoTz1HIcje39Wm4jDKdf19U8gI4ddQ3GYNS7NTKfAdVQSZe" crossorigin="anonymous"></script>
<script attr='' type="text/javascript">var ws;var host='<%= $url_data %>';</script>
<script attr='' type="text/javascript" src="<%= $url_util %>"></script>

</head>
<body onload="hackconnect()">
<div class="m-1">
	<h3>Hacker Checker</h3>
	<div class="m-1"><label>Server: </label><input type="text" id="bfvserver">
	<button type="button" id="check" class="btn btn-primary" onclick="hackcheck()">Check</button></div>
	<div class="container">
		<div id="response_container"></div>
	</div>
</div>
</body>
</html>

