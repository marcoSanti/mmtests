# ExtractMpas.pm
package MMTests::ExtractMpas;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractMpas";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @files = <$reportDir/*model-time.*>;
	my @stages;
	foreach my $file (@files) {
		my $stage;
		if ($file =~ /\/init_atomosphere_model-time/) {
			$stage = "init";
		}
		if ($file =~ /\/atmosphere_model-time/) {
			$stage = "model";
		}
		push @stages, $stage;

		$self->parse_time_all($file, $stage, 1);
	}

	my @ratioops;
	foreach my $stage (@stages) {
		push @ratioops, "elsp-$stage";
	}
}
