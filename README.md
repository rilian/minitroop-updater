Minitroopers controller
==============================

Controller script to manage recruited troopers in the game http://rilian.minitroopers.com

Features
========

* Crawl through all given trooper names
* Unlock missions
* Auto accept recruits
* Fight 3 times
* Go to Mission 3 times
* Raid 3 times
* Check if trooper needs upgrade
* Try to upgrade automatically (in development)
* In the end, return list of troopers that could upgrade
* Log all fights

How to use
==========

* Clone repo
* update `.rvmrc` or run `gem install bundler`
* `bundle install`
* update `troopers.yml` and put your troopers
* run `ruby update.rb` once a day
* Enjoy!

Output example
==============

```
$ ruby update.rb
Working on rbot22
chk=MLCGZT
Unlocking mission
Mission 0
Mission 1
Mission 2
Fighting 0
Fighting 1
Fighting 2
Raid 0
Raid 1
Raid 2
Raid 3
Raid 4
Checking if can upgrade
Has 4->12 money, and need 129 for upgrade
Finished successfully
```

Info
====

(c) 2013 rilian. You may use this software in learning purposes and without any warranty.
