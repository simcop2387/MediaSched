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
    directoryscan:
        include: 
            - \.(?:flv|wmv|asf|rm(vb)?|ogm|mkv|avi|mpe?g|m4v)$
        exclude: 
            - \(noauto\)
    player: Mplayer

* statefile
  where we keep track of the past, this is necessary right now (that will change).

* defaultlist
  the default when there isn't anything scheduled, will make this nicer in the future, this is looked for in the storage directories

* storage
  where we look to find any of the files we're after, videos, playlists, directories themselves, etc.

* calendar 
  where we can find an ical formatted file that tells us what we play

* timezone 
  the local timezone, this is to make sure that things all line up correctly

* directoryscan
  This is where you tell it what files to include when scanning a directory (it's always recursive) rather than an explicitly created playlist

  * include
    These regular expressions are ORed together to decide if a file should be played, if any of them match it'll consider the file for playback.

  * exclude
    These regular expressions are ORed together to decide if a file should be ignored and not played back under any circumstances.  There is an implicit one for the directories . and ..

* player
   Which player module to use, case sensitive.  Options are: Mplayer, Generic, and MPD.
  
* player_conf
  configuration for the player module
  ## MPD
  * host
    What host to connect to; defaults to localhost
  * port
    What port mpd is running on; defaults to 6600
  * password
    Password to use when connecting; defaults to no password
  * queuelength
    How long to queue up songs in the mpd playlist, in seconds; defaults to 1800 (half hour)
  * queuesongs
    Minimum number of songs in the playlist, used to prevent a clip longer than queuelength from keeping us from adding a song; defaults to 3 and it shouldn't need to be changed
  * extra options
    anything else you add will be passed to the constructor to Audio::MPD, for future additions to the module
  ## Mplayer
  * useedl
    Check for a $file.edl when playing files.  EDL files are "Edit Descision Lists" that let you tell mplayer to not play part of a file.  useful for skipping commercials in recorded videos.  defaults to 1; set to 0 to turn off
  ## Generic
  * binary
    What program to run for each file to play; no default, *this option is required*
  * args
    Additional arguments to the binary.  use %f to put the file in a specific place of the arguments.  defaults to: %f
 
# HISTORY
an older version of this software was originally written to use the database of WebCalendar (http://www.k5n.us/webcalendar.php) directly (from the 2007 era).
I've rewritten this part of it to instead use iCal directly so that more software can be supported. even using a local file so you don't have to have a constant connection to the database or the internet without having to setup a whole webserver, database, and php installation.
The older version is still in use by me, and has two forks, one for mplayer and one for mpd.  This version will get support for both via a pluggable interface.

# TODO
* Authentication for http/ftp for the calendar file.  This will let you use a private google calendar.
* Pluggable player support.
  * MPD
  * Mplayer
  * Generic command
* Some basic caching of the ical file, so that it works better on slow links.
* Finish the Pluggable source/storage code

    This is all about being able to collect things from other places (mostly mythtv in my case) for playback

# DEPENDENCIES
lots.  figure them out for yourself until i get it all packaged up nicely.
