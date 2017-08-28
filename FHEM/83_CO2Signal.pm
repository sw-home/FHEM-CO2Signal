=head1
        83_CO2Signal.pm

# $Id: $
        Version 0.1

=head1 SYNOPSIS
        Module for CO2Signal.com
        contributed by Stefan Willmeroth 08/2017

=head1 DESCRIPTION
       Minimize your carbon footprint by connecting FHEM to the CO2 Signal from http://www.co2signal.com/ and
       controlling FHEM devices based on the current fossil fuel percentage of electricity.

=head1 AUTHOR - Stefan Willmeroth
        swi@willmeroth.com (forum.fhem.de)
=cut

package main;

use strict;
use warnings;
use JSON;
require 'HttpUtils.pm';


##############################################
sub CO2Signal_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "CO2Signal_Set";
  $hash->{DefFn}     = "CO2Signal_Define";
  $hash->{GetFn}     = "CO2Signal_Get";
  $hash->{AttrList}  = "updateTimer";
}

###################################
sub CO2Signal_Set($@)
{
  return undef;
}

#####################################
sub CO2Signal_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  my $u = "wrong syntax: define <dev-name> CO2Signal <apiKey> <countryCode>";

  return $u if(int(@a) < 4);

  $hash->{apiKey} = $a[2];
  $hash->{countryCode} = $a[3];
  $hash->{STATE} = "Defined";

  $attr{$hash->{NAME}}{updateTimer} = "600" if (!defined $attr{$hash->{NAME}}{updateTimer});

  InternalTimer( gettimeofday() + 25, "CO2Signal_Timer", $hash, 0);

  Log3 $hash->{NAME}, 2, "$hash->{NAME} defined as CO2Signal for country '$hash->{countryCode}'";
  return undef;
}

#####################################
sub CO2Signal_Undef($$)
{
   my ( $hash, $arg ) = @_;

   RemoveInternalTimer($hash);
   Log3 $hash->{NAME}, 3, "--- removed ---";
   return undef;
}

#####################################
sub CO2Signal_Get($@)
{
  my ($hash, @args) = @_;

  return undef;
}

#####################################
sub CO2Signal_Timer
{
  my ($hash) = @_;
  my $name   = $hash->{NAME};

  my $pollingTimer   = AttrVal($name, "pollingTimer", 60);

  CO2Signal_UpdateStatus($hash);

  InternalTimer( gettimeofday() + $pollingTimer, "CO2Signal_Timer", $hash, 0);
}

#####################################
sub CO2Signal_UpdateStatus($)
{
  my ($hash) = @_;

  #### Get latest info from CO2 signal
  my $param = {
    url        => "https://api.co2signal.com/v1/latest?countryCode=$hash->{countryCode}",
    hash       => $hash,
    header     => { "Accept" => "application/json", "auth-token" => $hash->{apiKey} },
    timeout    => 10,
    callback   => \&CO2Signal_UpdateCallback,
    loglevel   => AttrVal($hash->{NAME}, "verbose", 4)
  };

  HttpUtils_NonblockingGet($param);

  return undef;
}

#####################################
sub CO2Signal_UpdateCallback($)
{
  my ($param, $err, $data) = @_;
  my $hash = $param->{hash};
  my $name = $hash->{NAME};
  my %readings = ();
  my $JSON = JSON->new->utf8(0)->allow_nonref;
  my $status = "Unknown";

  if($err ne "") {
    Log3 $name, 2, "error while requesting ".$param->{url}." - $err";
  }
  elsif($data ne "") {
    Log3 $name, 5, "$name returned: $data";

    my $parsed = $JSON->decode ($data);

    $status = $parsed->{status} if defined $parsed->{status};
    
    $readings{status} = $status;
    $hash->{STATE} = $status;

    foreach my $reading (keys %{$parsed->{data}}) {
      $readings{$reading} = int ( $parsed->{data}->{$reading} );
    }

    foreach my $unit (keys %{$parsed->{units}}) {
      $readings{$unit . "Unit"} = $parsed->{units}->{$unit};
    }

    #### Update Readings
    readingsBeginUpdate($hash);

    for my $get (keys %readings) {
      readingsBulkUpdate($hash, $get, $readings{$get});
    }
    readingsEndUpdate($hash, 1);
  }

  return undef;
}

1;

=pod
=begin html

<a name="CO2Signal"></a>
<h3>CO2Signal</h3>
<ul>
  <a name="CO2Signal_define"></a>
  <h4>Define</h4>
  <ul>
    <code>define &lt;name&gt; CO2Signal &lt;apiKey&gt; &lt;countryCode&gt;</code>
    <br/>
    <br/>
    Defines a connection to CO2 Signal using your API key and desired country code. <br/>
    Get your personal API key by registering at <a href="https://www.co2signal.com/">https://www.co2signal.com/</a>
    <br><br>
    Example:

    <code>define CO2Germany CO2Signal XXXXX DE</code><br>

  </ul>

  <a name="CO2Signal_Readings"></a>
  <h4>Readings</h4>
  <ul>
    <li><a name="carbonIntensity"><code>carbonIntensity</code></a>
      <br />How much carbon was emitted to produce electricity in selected country</li>
    <li><a name="fossilFuelPercentage"><code>fossilFuelPercentage</code></a>
      <br />Percentage of fossil fuels used to produce electricity in selected country</li>
  </ul>

  <a name="CO2Signal_Attr"></a>
  <h4>Attributes</h4>
  <ul>
    <li><a name="pollingTimer"><code>attr &lt;name&gt; pollingTimer &lt;Integer&gt;</code></a>
                <br />Interval for updating CO2 data, default is 10 minutes</li>
  </ul>
</ul>

=end html
=cut
