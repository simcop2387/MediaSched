#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes;
use IPC::Open2;
use IO::Handle;

my $_state;

require 'database.pl';
my $videopath = "/mnt/server/pub/Movies";

sub mp_addfile
{
  my $file = shift;

  print "filetoplay :: $file\n\n\n";
  system("/usr/bin/mplayer","$file");
}

sub addmovie
{
  my $time = shift;

  my $next = parseListEntry(mc_db_getlist($time));

  return unless defined($next);

  chomp $next;

  print "Adding movie, $next\n";
  mp_addfile($next);
}

sub addfiller
{
  my $time = shift;

  my $next = parseListEntry("!commercials:1\n!commedy:1\n!dbcart:2",-1024);

  return unless defined($next);

  chomp $next;

  print "Adding filler, $next\n";
  mp_addfile($next);
}


sub mainloop
{
   addmovie(time());
   addfiller();
   addfiller();
}

sub debug
{
 my $level = shift;
 my $debuglevel = 3;
 if ($debuglevel >= $level)
 {
   print @_;
 }
}

sub getDirectoryList
{
  my $parent=shift;


  my @prelist;
  my @list;  
  my @dir;

  opendir(my $dh, $parent);
  @prelist = readdir($dh);
  closedir($dh);

  @prelist = grep {!/\(noauto\)/i && !/^\.\.?$/} @prelist;

  #/(flv|wmv|asf|rm(vb)?|ogm|mkv|avi|mpe?g)$/i


  for (@prelist)
  { 
    push @dir, $_ if (-d "$parent/$_");
  }
  for (@prelist)
  {
    push @list, $parent."/".$_ if (-f "$parent/$_" && /(flv|wmv|asf|rm(vb)?|ogm|mkv|avi|mpe?g|m4v)$/i);
  }

  push @list, getFileList($parent."/".$_) for (@dir);

  return @list;
}

sub getFileList
{
  my $file = shift;
  if (-d $file)
  {
    return getDirectoryList("$file");
  }
  elsif (-T $file)
  {
    my $pl;
    open($pl, "<${videopath}/${file}");
    my @list = grep(!/^#/, <$pl>);
    close($pl);
    return @list;
  }
  else
  {
    return $file;
  }
}

sub readFileFromPlaylist
{
  my $file = shift;
  my $pl;

  if ($file =~ /^#/)
  {
    $file =~ s/^#//g;

    if (!exists($_state->{playlists}{$file}))
    {
      #state for this playlist doesn't exist so lets initalize it
      #we initilize to -1 because we increment it soon
      $_state->{playlists}{$file}=-1;
    }

    my @list=getFileList("$videopath/$file");
    s/\\/\//g for @list;
    {
      local $/ = "\r\n";
      chomp @list;
    };  

    #increment and mod
    $_state->{playlists}{$file}=($_state->{playlists}{$file}+1)%@list;
    return $list[$_state->{playlists}{$file}];
  }
  else
  {
    print "\n\nOpening <${videopath}/${file}\n\n\n";

    my @list=getFileList("$videopath/$file");

    s/\\/\//g for @list;
    {
      local $/ = "\r\n";
      chomp @list;
    };  

    return $list[rand($#list+1)];
  }
}

sub parseListEntry
{
  my $listout = shift;
  my $cid = shift;
  
  my $next;
  
  print "Listout:: $listout\n\n";
  
   if ($listout !~ /^!/)
   {
     $next = readFileFromPlaylist($listout);
   }
   else
   {
     $listout =~ s/!//g;
     my @lines = split(/\n/, $listout);
     #!The Beatles.m3u:1

     if ((!defined($_state->{multi}{$cid})) || ($_state->{multi}{$cid}{cont} ne join("\n", @lines)))
     {
       print("we have a new one! initilize!!! $cid\n");
       $_state->{multi}{$cid}{cont} = join("\n", @lines);
       $_state->{multi}{$cid}{lists} = [];
       $_state->{multi}{$cid}{count} = [];
       $_state->{multi}{$cid}{ratio} = [];
       $_state->{multi}{$cid}{lastint} = 0;

       for (@lines)
       {
         my ($list, $portion) = split(/:/, $_);
         $portion =~ s/[\r\n]//g;
         if (($list ne "") && defined($portion) && ($portion != 0))
         {
           push @{$_state->{multi}{$cid}{lists}}, $list;
           push @{$_state->{multi}{$cid}{count}}, 1;
           push @{$_state->{multi}{$cid}{ratio}}, $portion;
         }
       }
     }

     my $q;
     my $s;
    
     while(1)
     {
       #pick new list, then song
       $_state->{multi}{$cid}{lastint} = ($_state->{multi}{$cid}{lastint}+1) % @{$_state->{multi}{$cid}{count}};
       my $lastint = $_state->{multi}{$cid}{lastint};
       $q = ${$_state->{multi}{$cid}{ratio}}[($lastint+1)% @{$_state->{multi}{$cid}{ratio}}]/${$_state->{multi}{$cid}{ratio}}[$lastint];
       $s = ${$_state->{multi}{$cid}{count}}[($lastint+1)% @{$_state->{multi}{$cid}{count}}]/${$_state->{multi}{$cid}{count}}[$lastint];
            
       if ($s >= $q)
       {
         ${$_state->{multi}{$cid}{count}}[$lastint]++;
         $next = readFileFromPlaylist(${$_state->{multi}{$cid}{lists}}[$lastint]);
         last;
       }
     } 
   }
   
  return $next;
}

$_state = do "/home/music/moviestate.ddp";
  
print "$! :: $@\n" unless defined($_state);
$_state = {} unless defined($_state);

while(1)
{
my $st = mainloop(); #we only do this ONCE

open (FH_DUEL, ">/home/music/moviestate.ddp");
print FH_DUEL Dumper($_state);
close(FH_DUEL);
}

#print Dumper([getFileList($videopath)]);
