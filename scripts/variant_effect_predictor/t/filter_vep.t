use strict;
use warnings;
BEGIN { $| = 1;
	use Test::More;
	#plan tests => 6;
}

use FindBin qw($Bin);
use Data::Dumper;

# configure script
my $script = $Bin.'/../filter_vep.pl';
my $perl   = '/usr/bin/env perl';
my $cmd = "$perl $script";

my $txt = "$Bin\/testdata/filter.txt";
my $vcf = "$Bin\/testdata/filter.vcf";

my ($output, @lines);


## basic stuff

# help message
$output = `$cmd --help`;
ok($output =~ /filter_vep\.pl/, "help message");

my $opcmd = "$cmd -i $Bin\/testdata/filter.txt";

# error on no filters
$output = `$opcmd 2>&1`;
ok($output =~ /ERROR: No valid filters given/, "error on no filters");

# basic filter
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Uploaded_variation is rs114942253"`);
ok(scalar @lines, "basic filter");

# vcf input
@lines = grep {!/^\#/} split("\n", `$cmd -i $Bin\/testdata/filter.vcf -f "ID is rs114942253"`);
ok(scalar @lines, "VCF input");


## operators

# is
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Uploaded_variation is rs114942253"`);
ok(scalar @lines, "operator - is");

# ne
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Uploaded_variation ne rs114942253"`);
ok(!(grep {/rs114942253/} @lines), "operator - ne");

# ex
@lines = grep {!/^\#/} split("\n", `$opcmd -f "PolyPhen ex"`);
ok(scalar (grep {/PolyPhen/} @lines) == scalar @lines, "operator - ex");

# nex
@lines = grep {!/^\#/} split("\n", `$opcmd -f "PolyPhen nex"`);
ok(!(grep {/PolyPhen/} @lines), "operator - nex");

# not (another way of saying nex)
@lines = grep {!/^\#/} split("\n", `$opcmd -f "not PolyPhen"`);
ok(!(grep {/PolyPhen/} @lines), "operator - not");

# gt
@lines = grep {!/^\#/} split("\n", `$opcmd -f "AA_MAF gt 0.007036"`);
ok(!(grep {/rs115683257/} @lines), "operator - gt");

# gte
@lines = grep {!/^\#/} split("\n", `$opcmd -f "AA_MAF gte 0.007036"`);
ok((grep {/rs115683257/} @lines), "operator - gte");

# lt
@lines = grep {!/^\#/} split("\n", `$opcmd -f "AA_MAF lt 0.007036"`);
ok(!(grep {/rs115683257/} @lines), "operator - lt");

# lte
@lines = grep {!/^\#/} split("\n", `$opcmd -f "AA_MAF lte 0.007036"`);
ok((grep {/rs115683257/} @lines), "operator - lte");

# match
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Consequence matches stream"`);
ok((grep {/upstream/} @lines) && (grep {/downstream/} @lines), "operator - match");

# in
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Consequence in upstream_gene_variant,downstream_gene_variant"`);
ok((grep {/upstream/} @lines) && (grep {/downstream/} @lines), "operator - in list");

@lines = grep {!/^\#/} split("\n", `$opcmd -f "Consequence in $Bin\/testdata/filter.list"`);
ok(scalar (grep {/MRPL39/} grep {/SYNJ1/} @lines) == scalar @lines, "operator - in file");

# and
@lines = grep {!/^\#/} split("\n", `$opcmd -f "Uploaded_variation is rs116645811 and Feature is ENST00000567517"`);
ok(scalar (grep {/ENST00000567517/} grep {/rs116645811/} @lines) == scalar @lines, "operator - and");


## advanced/nested filters

@lines = grep {!/^\#/} split("\n", `$opcmd -f "CDS_position is 3060 and (cDNA_position is 3060 or cDNA_position is 3068)"`);
is(scalar @lines, 2, "nested 1");
ok($lines[0] =~ /ENST00000382499/ && $lines[1] =~ /ENST00000433931/, "nested 2");

@lines = grep {!/^\#/} split("\n", `$opcmd -f "(Consequence is missense_variant and not (SIFT is tolerated or PolyPhen is benign)) or (Consequence is regulatory_region_variant and GMAF > 0.1)"`);
is(scalar @lines, 50, "nested 3");

@lines = grep {!/^\#/} split("\n", `$opcmd -f "(Consequence is missense_variant" 2>&1`);
ok($lines[0] =~ /^ERROR/, "nested error 1");

@lines = grep {!/^\#/} split("\n", `$opcmd -f "(Consequence is missense_variant and not (SIFT is tolerated or PolyPhen is benign) or (Consequence is regulatory_region_variant and GMAF > 0.1)" 2>&1`);
ok($lines[0] =~ /^ERROR/, "nested error 2");


## options

# only matched
@lines = grep {!/^\#/} split("\n", `$cmd -i $Bin\/testdata/filter.vcf -only_matched -f "Uploaded_variation is rs116645811 and Feature is ENST00000567517"`);
ok(!(grep {/ENST00000352957/} @lines), "only matched");

# list fields
@lines = grep {!/^\#/} split("\n", `$cmd -i $Bin\/testdata/filter.vcf -list`);
ok(scalar @lines eq 57, "list fields") or diag("Got ".(scalar @lines).", expected 57");

# count
$output = `$cmd -i $Bin\/testdata/filter.vcf -f "SIFT is deleterious" -c`;
ok($output eq "24\n", "count lines");

# ontology
if(can_connect('ensembldb.ensembl.org')) {
  @lines = grep {!/^\#/} split("\n", `$opcmd -ontology -f "Consequence is coding_sequence_variant"`);
  ok(
    (grep {/missense_variant/} @lines) &&
    (grep {/synonymous_variant/} @lines),
    "ontology"
  );
}
else {
  print STDERR "# could not contact ensembldb.ensembl.org, skipping DB tests\n";
}

done_testing();

sub can_connect {
  my $host = shift;
  my $port = shift || 3306;

  eval { use DBI; };
  return 0 if $@;

  my $dsn = sprintf(
    "DBI:mysql(RaiseError=>1):host=%s;port=%i",
    $host,
    $port
  );
  my $dbh = DBI->connect($dsn, 'anonymous', '');

  if($@) {
    return 0;
  }

  else {
    return 1;
  }
}
