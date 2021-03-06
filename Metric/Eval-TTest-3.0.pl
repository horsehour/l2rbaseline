#!
# author: Jun Xu and Tie-Yan Liu
use strict;
use Statistics::DependantTTest;
use Statistics::Distributions;

my ($fnInputA, $fnInputB, $fnOutput) = @ARGV;
my $argc = $#ARGV+1;
if($argc != 3)
{
		print "Invalid command line.\n";
		print "Usage: perl t-test.pl argv[1] argv[2] argv[3]\n";
		print "argv[1]: evaluation file A\n";
		print "argv[2]: evaluation file B\n";
		print "argv[3]: result (output) file\n";
		exit -1;
}


my %hsQueryPerf;
my %hsTTestResult;

ReadInputFile($fnInputA, "A");
ReadInputFile($fnInputB, "B");

open(FOUT, ">$fnOutput") or die "$!: Cannot create $fnOutput\n";
print FOUT "t-test results for A: $fnInputA and B: $fnInputB\n\n\n";
print FOUT "Measure\tNumber of queries\tMean A\tMean B\tt-value\tp-value\n";
my @measures = sort {MeasureStringComp($a) <=> MeasureStringComp($b)} keys(%hsQueryPerf);

for(my $i = 0; $i < @measures; $i ++)
{
    my $curMeasure = $measures[$i];
    my @A_values;
    my @B_values;
    my $meanA;
    my $meanB;
    foreach my $qid (keys(%{$hsQueryPerf{$curMeasure}}))
    {
        if (exists($hsQueryPerf{$curMeasure}{$qid}{"A"})
         && exists($hsQueryPerf{$curMeasure}{$qid}{"B"}) )
        {
            push @A_values, $hsQueryPerf{$curMeasure}{$qid}{"A"};
            $meanA += $hsQueryPerf{$curMeasure}{$qid}{"A"};
            push @B_values, $hsQueryPerf{$curMeasure}{$qid}{"B"};
            $meanB += $hsQueryPerf{$curMeasure}{$qid}{"B"};
        }
        else
        {
            die "Empty value for $curMeasure, qid = $qid\n";
        }
    }
    my $numQuery = @A_values;
    $meanA /= $numQuery;
    $meanB /= $numQuery;
    
    my $t_test = new Statistics::DependantTTest;
    $t_test->load_data('A',@A_values);
    $t_test->load_data('B',@B_values);
    my ($t_value, $deg_freedom) = $t_test->perform_t_test('A','B');
    my ($p_value) = Statistics::Distributions::tprob($deg_freedom, $t_value);

    print FOUT "$curMeasure\t$numQuery\t$meanA\t$meanB\t$t_value\t$p_value\n";
}
close(FOUT);

#subs
sub ReadInputFile
{
    my ($fnInput, $flag) = @_;
    open(FIN, $fnInput) or die "$!: Cannot open file $fnInput.\n";
    while(defined(my $ln = <FIN>))
    {
        chomp($ln);
        if ($ln =~ m/^precision of query(\d+)\:\s+(.*?)$/i)
        {
            my $qid = $1;
            my $strPrec = $2;
            my @precs = split(/\s+/, $strPrec);
            for(my $idx = 1; $idx <= @precs; $idx ++)
            {
                my $measure = "prec\@$idx";
                $hsQueryPerf{$measure}{$qid}{$flag} = $precs[$idx - 1];
            }

        }
        elsif ($ln =~ m/^map of query(\d+)\:\s+(.*?)$/i)
        {
            my $qid = $1;
            my $strMap = $2;
            $hsQueryPerf{"map"}{$qid}{$flag} = $strMap;
        }
        elsif ($ln =~ m/^ndcg of query(\d+)\:\s+(.*?)$/i)
        {
            my $qid = $1;
            my $strNdcg = $2;
            my @ndcgs = split(/\s+/, $strNdcg);
            for(my $idx = 1; $idx <= @ndcgs; $idx ++)
            {
                my $measure = "ndcg\@$idx";
                $hsQueryPerf{$measure}{$qid}{$flag} = $ndcgs[$idx - 1];
            }
        }
    }
    close(FIN);
}

sub MeasureStringComp
{
    my $strMeasure = $_[0];
    my $map = 0;
    my $ndcg = 500;
    my $prec = 1000;
    if ($strMeasure =~ m/^map/i)
    {
        return $map;
    }
    elsif ($strMeasure =~ m/^ndcg\@(\d+)$/i)
    {
        my $iPos = $1;
        die "Error: Invalide measure string $strMeasure\n"if ($iPos > 100);
        return $ndcg + $iPos;
    }
    elsif ($strMeasure =~ m/^prec\@(\d+)$/i)
    {
        my $iPos = $1;
        die "Error: Invalide measure string $strMeasure\n" if ($iPos > 100);
        return $prec + $iPos;
    }
    else
    {
        die "Error: Invalide measure string $strMeasure\n";
    }
}
