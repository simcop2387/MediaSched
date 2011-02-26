package Mythtv;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;

use POE qw(Session);
use Data::Dumper;
use Net::Telnet;

my $ses = POE::Session->create(
  package_states => 
    [
      Mythtv => [ qw(_start getlist updatelist parselist matchshow) ],
	],
	heap =>{shows=>[]});
	
sub _start
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	$kernel->alias_set("Mythtv");
	$kernel->call("Mythtv","updatelist"); #ensure that we do this
}

sub getlist
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	return $heap->{shows}; #return the shows
}

sub updatelist
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	eval {
 #    my $t = new Net::Telnet (Timeout => 10, Prompt => '/# /');
 #    $t->open(host => "mythmaster", port => "6546");
 #    $t->waitfor("/# /");
 #    my $lines = [$t->cmd("query recordings")];
    #print @$lines;

 #    $kernel->call(Mythtv=>parselist=>$lines);
	}; #do it in eval so that it'll keep from making the whole thing fail
 #    $kernel->delay(updatelist => 30*60); #set an update for 30 minutes in the future
}

sub parselist
{
	my ($kernel, $heap, $lines) = @_[KERNEL, HEAP, ARG0];

    $heap->{shows} = [];
    for my $line (@$lines)
    {
    	if ($line =~ /^(\d+)\s+(\d+-\d+-\d+T\d+:\d+:\d+)\s+(.*?)\s*-"(.*)"/)
    	{
    		my $episode = {channel => $1,
    			           airtime => $2,
    			           name => $3,
    			           episode => $4};
    		
    		push @{$heap->{shows}}, $episode;
    	}
    }
    
    #print Dumper($heap);
}

sub matchshow
{
	my ($kernel, $heap, $regex) = @_[KERNEL, HEAP, ARG0];

    my @matched = grep {$_->{name} =~ /$regex/} @{$heap->{shows}};
    
    my $hash = $matched[rand @matched];
    my $time = $hash->{airtime};
    
    $time =~ s/\D//g; #all we have to do is just remove all non digits? sweet.
      
    my $filename = $hash->{channel}. "_".$time.".mpg";
    return $filename;
}

1;
