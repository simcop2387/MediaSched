package MediaSched::Lists;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;
use Data::Dumper;
use List::Util qw/reduce/;

use MediaSched::State;
use MediaSched::Log;
use MediaSched::Calendar;
use MediaSched::MediaConfig;

use POE qw(Session);

my $ses = POE::Session->create(
  package_states => 
    [
      "MediaSched::Lists" => [ qw(_start getepisode) ],
	],
	heap =>{shows=>[], includeregex=>undef, excluderegex=>undef});

sub _start
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	$kernel->alias_set("Lists");
	my $scan = get_config("directoryscan");
	
	my $include = reduce {qr/$a|$b/i} map {qr/$_/i} @{$scan->{include}};
	my $exclude = reduce {qr/$a|$b/i} map {qr/$_/i} @{$scan->{exclude}};
	
	$heap->{excluderegex} = $exclude;
	$heap->{includeregex} = $include;
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
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	debug 3, "Getepisode called";
	
	my ($list, $id) = $kernel->call(Calendar => get_sched => time());
	
	if (!defined($id))
	{#once i have this as recursive, i'll move this into a real file
		($list, $id) = (get_config("defaultlist"), -1);
	}
	
	debug 3, "Got List $id";
	
	my ($file, $basename) = resolveEntry($list, $id, $heap);
	
	if ($file =~ /^mythtv~(.*)/) #grab the mythtv stuff, i'll extend this later to support specific episodes
	{
		$file = $kernel->call("Mythtv", "matchshow", $1);
		$file = findentity($file); #resolve the path
	}
	
	return ($file, $basename);
}

sub resolveEntry
{
	my $list = shift;
	my $id = shift;
	my $heap = shift;
	
	my $filename = parseListEntry($list, $id);
	my ($file, $basename) = readFileFromPlaylist($filename, $id, $heap);
	
	return ($file, $basename);
}

sub findentity
{
	my $entity = shift; #some file or directory to find
	
	for my $path (@{get_config("storage")})
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
  my $heap=shift;

  my @prelist;
  my @list;  
  my @dir;

  opendir(my $dh, $parent);
  @prelist = readdir($dh);
  closedir($dh);

  @prelist = grep {$_ !~ $heap->{excluderegex} && !/^\.\.?$/} @prelist;


  for (@prelist)
  { 
    push @dir, $_ if (-d "$parent/$_");
  }
  for (@prelist)
  {
    push @list, $parent."/".$_ if (-f "$parent/$_" && $_ =~ $heap->{includeregex});
  }

  push @list, getFileList($parent."/".$_, $heap) for (@dir);

  return @list;
}

sub getFileList
{
  my $filename = shift;
  my $heap = shift;
  my $file = findentity($filename);
  
  if (-d $file)
  {
    return join "\n", getDirectoryList($file, $heap);
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
  my $heap = shift;
  my $pl;
  
  print "Readfilefromplaylist : $file :: $stateid\n";

  print Dumper($_state);
  sleep 10;  

  if ($file =~ /^%/)
  { # NTS, this doesn't correctly work with $basename yet, update this!!!!
    $file =~ s/^%//g;
    debug 3, "$stateid :: $file";

    if (!exists($_state->{playlists}{$stateid}))
    {
      #state for this playlist doesn't exist so lets initalize it
      #we initilize to -1 because we increment it soon
      $_state->{playlists}{$stateid}=-1;
    }

    my $list=getFileList($file, $heap);
	debug 3, "$stateid :: $list";
    my @list=sort split(/\n/, $list);
	debug 3, Dumper(\@list);

    #increment and mod
    $_state->{playlists}{$stateid}=($_state->{playlists}{$stateid}+1)%@list;
    return $list[$_state->{playlists}{$stateid}];
  }
  else
  {
  	$file =~ s/[\r\n]+$//; # remove trailing newlines
    print "\n\nOpening <",$file," from ",findentity($file),"\n\n\n";

    my $list=getFileList($file, $heap);
    
    if ($list =~ /\n./) # look for a newline
    {
    	my ($next, $basename) = resolveEntry($list, $stateid."::".$file, $heap);#we append the file to the id, so that we get separate ids
    	return ($next, $basename);
    }
    else
    {
    	return ($list, $file);
    }
  }
}

#NOTE TO SELF, make a good comment here, this is insidiously complex code that should be cleaned up but almost can't be.
# so someone looking at it thinks that you're insane
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
         my ($list, $portion) = ($_ =~ m/^(.*):(\d+)\s*$/g);
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
