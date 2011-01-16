package Lists;

use strict;
use warnings;
use Data::Dumper;

use State;
use Log;
use DB;

use POE qw(Session);

my $ses = POE::Session->create(
  package_states => 
    [
      Lists => [ qw(_start getepisode) ],
	],
	heap =>{shows=>[]});


our $basepaths = ["/mnt/server/pub/Movies/",
                  "/mythtv/record/",
                  "/mythtv2/record/",
		  "/mnt/ryans/torrents/",
		  "/home/music/television/defaults/"];

my $videoregex = qr/(flv|wmv|asf|rm(vb)?|ogm|mkv|avi|mpe?g|m4v)$/i;

sub _start
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	$kernel->alias_set("Lists");
	#nothing to do fucking POE
}

sub cleanandsplit
{
	my @list=map {split /\n/,$_} @_;
	
    s/\\/\//g for @list;
    {
      local $/ = "\r\n";
      chomp @list;
      $/ = "\n"; #handle unix ones too, i'll be making a few files
      chomp @list;
    };
    
    return @list;
}

sub getepisode
{
	my ($kernel) = $_[KERNEL];
	debug 3, "Getepisode called";
	
	my ($list, $id) = DB::mc_db_getlist(time);
	
	if (!defined($id))
	{#once i have this as recursive, i'll move this into a real file
		($list, $id) = ("masterdefault.lst", -1);
#		($list, $id) = ("!TV Shows/Futurama:7\n!simpsons:17\n!The Three Stooges:15\n!TV Shows/Family Guy/test.channel.list:11\n!TV Shows/Robot Chicken:4", -1023);
#		($list, $id) = ("!TV Shows/Futurama:1\n!mythtv~Family Guy:1", -1024);
	}
	
	debug 3, "Got List $id";
	
	my $file = resolveEntry($list, $id);
	
	if ($file =~ /^mythtv~(.*)/) #grab the mythtv stuff, i'll extend this later to support specific episodes
	{
		$file = $kernel->call("Mythtv", "matchshow", $1);
		$file = findentity($file); #resolve the path
	}
	
	return $file;
}

sub resolveEntry
{
	my $list = shift;
	my $id = shift;
	
	my $filename = parseListEntry($list, $id);
	my $file = readFileFromPlaylist($filename, $id);
	
}

sub findentity
{
	my $entity = shift; #some file or directory to find
	
	for my $path (@$basepaths)
	{
		if (-e $path . "/" . $entity)
		{
			return $path . "/" . $entity;
		}
	}
	
	return $entity; #let non-existant shit fall through, this'll be used for myth stuff
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
    push @list, $parent."/".$_ if (-f "$parent/$_" && /$videoregex/);
  }

  push @list, getFileList($parent."/".$_) for (@dir);

  return @list;
}

sub getFileList
{
  my $filename = shift;
  my $file = findentity($filename);
  
  if (-d $file)
  {
    return join "\n", getDirectoryList($file);
  }
  elsif (-T $file)
  {
    my $pl;
    open($pl, "<",$file);
    my @list = grep(!/^#/, <$pl>);
    close($pl);
    return join "", @list;
  }
  else
  {
    return $file;
  }
}

sub readFileFromPlaylist
{
  my $file = shift;
  my $stateid = shift || $file;
  my $pl;
  
  print "RFFPL\n$file\n$stateid\n\n";
  
  if ($file =~ /^%/)
  {
    $file =~ s/^%//g;
    debug 3, "$stateid :: $file";

    if (!exists($_state->{playlists}{$stateid}))
    {
      #state for this playlist doesn't exist so lets initalize it
      #we initilize to -1 because we increment it soon
      $_state->{playlists}{$stateid}=-1;
    }

    my $list=getFileList($file);
	debug 3, "$stateid :: $list";
    my @list=sort split(/\n/, $list);
	debug 3, Dumper(\@list);

    #increment and mod
    $_state->{playlists}{$stateid}=($_state->{playlists}{$stateid}+1)%@list;
    return $list[$_state->{playlists}{$stateid}];
  }
  else
  {
    print "\n\nOpening <",$file," from ",findentity($file),"\n\n\n";

    my $list=getFileList($file);
    
    if ($list =~ /\n./)
    {
    	my $next=resolveEntry($list, $stateid."::".$file);#we append the file to the id, so that we get separate ids
    	return $next;
    }
    else
    {
    	return $list
    }
  }
}

sub parseListEntry
{
  my $listout = shift;
  my $cid = shift;
  
  my $next;
  
  debug 4, "Listout:: $listout\n\n";
  
   if ($listout !~ /^!/)
   {
   	 if ($listout =~ /\n./) #check if its more than one line
   	 {
   	 	my @lines = cleanandsplit($listout);
   	 	$next = $lines[rand @lines];
   	 }
   	 else
   	 {
   	 	$next = $listout;
   	 }
   }
   else
   {
     $listout =~ s/^!//mg; #remove them from the beginning only
     my @lines = cleanandsplit($listout);
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
         my ($list, $portion) = m/^(.*):(\d+)$/g; 
         #split(/:/, $_);
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
         $next = ${$_state->{multi}{$cid}{lists}}[$lastint];
         last;
       }
     }
   }
   
  return $next;
}
