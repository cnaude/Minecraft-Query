#!/usr/pkg/bin/perl
#
use strict;
use IO::Socket;
use CGI qw(:standard);
use Image::Magick;
use Encode qw/encode decode/;

# Nice blocky font
my $font = 'minecraft_font_by_pwnage_block-d37t6nb.ttf';
# Terrain file from minecraft.jar
my $terrain = 'terrain.png';

my $host = param('host');
unless ($host) { $host = 'minecraft.sdf.org'; }
my $port = param('port') or '25565';
unless ($port) { $port = '25565'; }
my ($motd,$online,$max);
my $status = "UP";
my $text_color = "yellow";
if (param('c')) { $text_color = param('c'); }

if (param('h')) {
  print "Content-type: text/plain\n\n";
  print <<HTML;
Available options:
 motd = Override motd from server
 host = Hostname or IP
 port = TCP port
 c = Text color
 t = Top texture (grass, snow or myc) 
HTML
  exit 0;
}

my %blocks = (
  'grass' => '16x16+48+0',
  'snow' => '16x16+64+64',
  'myc' => '16x16+208+64',
  'DOWN' => '16x16+16+128',
  'UP' => '16x16+32+144',
  'dirt' => '16x16+32+0',
);

my $sock = new IO::Socket::INET (
  PeerAddr => $host,
  PeerPort => $port,
  Proto => 'tcp',
) or $status = "DOWN";

if ($status ne "DOWN") {
  my $FE = "\xFE";
  my $A7 = "\xA7";
  my $data = "";
  $sock->send($FE);
  $sock->recv($data,1024);
  $sock->close;
  $data =~ s/$FE//g;
  substr($data, 0,3) = "";
  ($motd,$online,$max) = split ($A7, $data);
  # Convert motd to UTF8
  $motd = decode("UCS-2BE", $motd);
  $online =~ s/\D//g;
  $max =~ s/\D//g;
  $status = "UP";
} else {
  $online = "???";
  $max = "???";
}

my $image = Image::Magick->new(size=>'384x96',background=>'black');
my $wool = Image::Magick->new;
my $grass = Image::Magick->new;
my $background = Image::Magick->new;

my $texture_size = "32";

$wool->read(filename=>$terrain);
$wool->Crop(geometry=>$blocks{$status});
$wool->Resize(geometry=>"${texture_size}x${texture_size}");

my $top = param('t');
unless (exists $blocks{$top}) { $top = 'grass'; }
$grass->read(filename=>$terrain);
$grass->Crop(geometry=>$blocks{$top});
$grass->Resize(geometry=>"${texture_size}x${texture_size}");

my $bg = param('b');
unless (exists $blocks{$bg}) { $bg = 'dirt'; }
$background->read(filename=>$terrain);
$background->Crop(geometry=>$blocks{$bg});
$background->Resize(geometry=>"${texture_size}x${texture_size}");

$image->ReadImage('xc:black');
my $point_size=18;
$image->Draw(fill=>$text_color, primitive=>'rectangle', points=>'0,0 10,100');
$image->Composite(image=>$background,compose=>'over',tile=>'true');
for (my $i = $texture_size; $i<=384; $i+=$texture_size) {
  $image->Composite(image=>$grass,compose=>'over',geometry=>"+${i}+0");
}
for (my $i = 0; $i<=64; $i+=$texture_size) {
  $image->Composite(image=>$wool,compose=>'over',geometry=>"+0+${i}");
}
my $hpos = 48;
if (param('motd')) { $motd = param('motd'); }
# Shadow text
my $shadow_color='black';
my $line1_pos = 28;
my $line2_pos = 48;
my $line3_pos = 68;
my $line4_pos = 88;
my $y_offset = 2;
my $x_offset = 2;
$image->Annotate(font=>$font, x=>($hpos - $x_offset), y=>($line1_pos + $y_offset), pointsize=>$point_size, fill=>$shadow_color, text=>"$motd");
$image->Annotate(font=>$font, x=>($hpos - $x_offset), y=>($line2_pos + $y_offset), pointsize=>$point_size, fill=>$shadow_color, text=>"Host: $host");
$image->Annotate(font=>$font, x=>($hpos - $x_offset), y=>($line3_pos + $y_offset), pointsize=>$point_size, fill=>$shadow_color, text=>"Players: $online/$max");
$image->Annotate(font=>$font, x=>($hpos - $x_offset), y=>($line4_pos + $y_offset), pointsize=>$point_size, fill=>$shadow_color, text=>"Status: $status");

$image->Annotate(font=>$font, x=>$hpos, y=>$line1_pos, pointsize=>$point_size, fill=>$text_color, text=>"$motd");
$image->Annotate(font=>$font, x=>$hpos, y=>$line2_pos, pointsize=>$point_size, fill=>$text_color, text=>"Host: $host");
$image->Annotate(font=>$font, x=>$hpos, y=>$line3_pos, pointsize=>$point_size, fill=>$text_color, text=>"Players: $online/$max");
$image->Annotate(font=>$font, x=>$hpos, y=>$line4_pos, pointsize=>$point_size, fill=>$text_color, text=>"Status: $status");

print "Content-length: " . $img->Get(filesize) . "\n\n";
print "Content-type: image/png\n\n";
binmode STDOUT;
$image->Write('png:-');
