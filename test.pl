#!/usr/bin/perl

           use Net::Telnet ();
           $t = new Net::Telnet (Timeout => 100,
                                 Prompt => '/\\# /');
           $t->open(host => "mythmaster", port => "6546");
           $t->waitfor("/\\# /");
           @lines = $t->cmd("query recordings");
           print @lines;

