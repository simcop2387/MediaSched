package DB;

use strict;
use warnings;

use Log;

use DBI;
use POSIX;
use Data::Dumper;

use Date::Calc qw(Date_to_Days);

my $dsn = "DBI:mysql:database=Sked2;host=radio";
my $dbh = DBI->connect($dsn, "root", "oscar", {RaiseError => 1}) or print "CONNECT FAILED\n";

sub mc_db_getlist
{
  my $curtime = shift;
  debug 2, "DB: Getting playlist";
  #we only look to make sure it happened at some point in the past, stuff in the future can't affect us
  my $sth = $dbh->prepare('SELECT * FROM `webcal_entry` WHERE (`cal_time` < ?) AND (`cal_date` <> -1)');
  my $caltime = POSIX::strftime("%k%M%S",localtime($curtime));
  my $caldate = POSIX::strftime("%G%m%d",localtime($curtime));
  my $caldiff = substr($caltime, 0,2)*60+substr($caltime,2,2);

  $sth->execute($caltime) or print "EXECUTE FAILED\n";

  my @results;
  while (my $i = $sth->fetchrow_hashref())
  {
    my $ctp = sprintf("%06d", $i->{cal_time});
    my $ct = substr($ctp,0,2)*60+substr($ctp,2,2);
    my $cd = $caldiff-$ct;

    if ($cd < $i->{cal_duration})
    {
     push @results,$i;
    }
  }

# print Dumper(\@results);

  my @real;

  for my $i (@results)
  {
    $sth = $dbh->prepare('SELECT `cal_status` FROM `webcal_entry_user` WHERE `cal_id` = ? LIMIT 1');
    $sth->execute($i->{cal_id});

    push @real, $i if ($sth->fetchrow_array() ne "D");
  }

#  print Dumper(\@real);

  for my $i (@real)
  {
    if ($i->{cal_type} eq "E")
    {
      debug 3, "Got simple entry\n";
      #simple entry, no repeat should be needed
      if ($i->{cal_date} eq $caldate)
      {
        #times match up, dates match up, what more do i need?
        return ($i->{cal_description}, $i->{cal_id});
      }
    }
    elsif ($i->{cal_type} eq "M")
    {
      #repeated entry more complex, i need repeat type and dates
      debug 3, "Got repeating entry\n";

      $sth = $dbh->prepare('SELECT * FROM `webcal_entry_repeats` WHERE `cal_id` = ?');
      $sth->execute($i->{cal_id});
      my $hr = $sth->fetchrow_hashref();

      if ($hr->{cal_type} eq "daily")
      {
        debug 3, "got daily\n";
        #we check if we are before the end date, but after the begin date, if we are then
        #we are golden
        debug 3, Dumper($hr,$i);

        debug 3, Dumper([$caldate<=$hr->{cal_end}, $caldate >= $i->{cal_date}, mc_db_datediff_day($caldate, $i->{cal_date}) %  $hr->{cal_frequency}]);
        if (($caldate<=$hr->{cal_end}) && ($caldate >= $i->{cal_date}) && 
            ((mc_db_datediff_day($caldate, $i->{cal_date}) % $hr->{cal_frequency}) == 0))
        {
          #we are good
          return ($i->{cal_description}, $i->{cal_id});
        }
      }
      elsif ($hr->{cal_type} eq "weekly")
      {
        #this is a bit harder i need to get the DOW of the item and do more checking
        debug 3,"Entry is weekly\n";

        if (($caldate < $hr->{cal_end}) && ($caldate > $i->{cal_date}))
        {
          my ($y1, $m1, $dy1) = ($caldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
          my ($y2, $m2, $dy2) = ($i->{cal_date} =~ /(\d\d\d\d)(\d\d)(\d\d)/);

          my $dow1 = Day_of_Week($y1, $m1, $dy1) % 7;
          my $sow1 = Date_to_Days($y1, $m1, $dy1) - $dow1;
          my $dow2 = Day_of_Week($y2, $m2, $dy2) % 7;
          my $sow2 = Date_to_Days($y2, $m2, $dy2) - $dow2;

          my $wdiff = ($sow1 - $sow2) / 7;

          if (($wdiff % $hr->{cal_frequency}) == 0)          
          {
            
          }
        }
      }
    }
  }

  #crap
  debug 1, "shit list not found\n";
#  return "simpsons";
  return;
}

sub mc_db_datediff_day
{
  my $d1 = shift;
  my $d2 = shift;

  my ($y1, $m1, $dy1) = ($d1 =~ /(\d\d\d\d)(\d\d)(\d\d)/);
  my ($y2, $m2, $dy2) = ($d2 =~ /(\d\d\d\d)(\d\d)(\d\d)/);

  my $ds1 = Date_to_Days($y1, $m1, $dy1);
  my $ds2 = Date_to_Days($y2, $m2, $dy2);

  my $dd = abs($ds2-$ds1);
  
  return $dd;
}

1;
