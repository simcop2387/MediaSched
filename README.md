# DISCLAIMER!
I won't claim this will work for anyone else yet.

# CONFIG
There's a simple config.yml file here, should be mostly self explanitory.
    statefile: tv.state
    defaultlist: masterdefault.lst
    storage:
        - /mnt/server/pub/Movies/
        - /mythtv/record/
        - /mythtv2/record/
        - /mnt/ryans/torrents/
        - /home/music/television/defaults/
    calendar: http://www.google.com/calendar/ical/pipnb40ro3uhnce0oc36a0n0sk%40group.calendar.google.com/public/basic.ics
    timezone: America/New_York

statefile
:  where we keep track of the past, this is necessary right now (that will change).

defaultlist
:  the default when there isn't anything scheduled, will make this nicer in the future, this is looked for in the storage directories

storage
:  where we look to find any of the files we're after, videos, playlists, directories themselves, etc.

calendar 
:  where we can find an ical formatted file that tells us what we play

timezone 
:  the local timezone, this is to make sure that things all line up correctly

# HISTORY
an older version of this software was originally written to use the database of WebCalendar (http://www.k5n.us/webcalendar.php) directly (from the 2007 era).
I've rewritten this part of it to instead use iCal directly so that more software can be supported. even using a local file so you don't have to have a constant connection to the database or the internet without having to setup a whole webserver, database, and php installation.
The older version is still in use by me, and has two forks, one for mplayer and one for mpd.  This version will get support for both via a pluggable interface.

# TODO
* Authentication for http/ftp for the calendar file.  This will let you use a private google calendar.
* Pluggable player support.
* * MPD
* * Mplayer
* * Generic command
* Customized inclusion and exclusion rules for file (check back tomorrow)
