# hackerchecher
mojolicious::lite script for checking BFV servers for cheaters

This script relies on https://api.gametools.network/docs. It creates links to https://bfvhackers.com.

Installation on debian:

```
apt-get install libmojolicious-perl
```

to run:
```
nohup perl hackerchecker.pl &
```

for output:
```
tail -f nohup.out
```
