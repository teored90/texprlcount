#!/usr/bin/perl
#
# This script estimates the word count of a .tex file according to the PRL
# guidelines for length, available at
# 
# https://journals.aps.org/authors/length-guide
#
# The TeXcount is used for words and equations, while the aspect ratio of
# figures is obtained from the latex .log file. If the file is not present,
# an error will be raised
#

use strict;
use POSIX;
use Math::Round;
use warnings;

if ($#ARGV < 0) {
	print "Usage: prllength.pl filename\n";
	exit;
}
my $filename = $ARGV[0];
$filename =~ s{\.[^.]+$}{};

if (!-e "$filename.tex") {
	print "The file $filename.tex doesn't exist\n";
	exit;
}

#We open the tex file and the log file
open(my $texfileh,"<$filename.tex") || die "File $filename.tex not found.";
open(my $logfileh,"<$filename.log") || die "File $filename.log not found. Please compile the .tex file";

local $/; 	# Allows for the whole file to be read into a string (otherwise, 
			# it would be line-wise)
my $logfile = <$logfileh>;
my $texfile = <$texfileh>;

close $logfileh;
close $texfileh;

# We strip comments from the tex file
$texfile =~ s/%[^\n]*//g;

# We count the number of characters in the abstract
my $abstract;
($abstract) = $texfile =~ /\\begin\{abstract\}(.*?)\\end\{abstract\}/s;

my $totalcount = 0; # Total word count

# We use texcount for evaluating the total word count given by text, captions, 
# headers, inline equations (1 eq = 1 word) and display equation (1 eq = 16
# words)
my $texcount = `texcount $filename.tex -utf8 -sum=1,1,1,0,0,1,0`;
print "\n";
print "Words in text, headers and equations\n";
print "------------------------------------\n";

print "$texcount";

($totalcount) = $texcount =~ /Sum\scount:\s(\d+)/;

# We now address multiline equations. First, we match the environments that can contain multiline equations: align, split, eqnarray etc

my (@aligns) = $texfile =~ /\\begin\{(equation|align\*?|eqnarray)\}(.*?)\\end\{\1\}/sg;

my $mathlinecount;
for (my $i = 1; $i <= $#aligns; $i = $i + 2) {
	$mathlinecount += () = $aligns[$i] =~ /\\\\/g;
	$mathlinecount++;
}
#Now we check for $$ .. $$
(@aligns) = $texfile =~ /\$\$(.*?)\$\$/sg;
foreach (@aligns) {
		$mathlinecount++;
}
#And for \[ \]
(@aligns) = $texfile =~ /\\\[(.*?)\\\]/sg;
foreach (@aligns) {
		$mathlinecount++;
}
$totalcount += 16*$mathlinecount;

print "Number of displayed math lines: $mathlinecount\n\n";


# We now address the image estimated word count. PRL length guide suggests the
# formula
#
#				      150              150 * height
# (word count) = -------------- + 20 = ------------ + 20
#                 aspect ratio             width
#
# where aspect ratio is width / height.
#
# We use the pdflatex log file for this task. In the log file, for each
# included graphics an output similar to the following appears
#
# > <filename.pdf, id=116, 199.74625pt x 108.405pt>
# > File: filename.pdf Graphic file (type pdf)
# >
# > <use filename.pdf>
# > Package pdftex.def Info: filename.pdf used on input line 313.
# > (pdftex.def)             Requested size: 221.3985pt x 120.16223pt.
#

my $imageswordcount = 0;

my @images;

# Extract the names of images from the log file
@images = $logfile =~ /(?<=\<use )(.*?)(?=\>)/g;

# Now look in the tex file to check wether they are in a single-column or in a
# double-column figure environment
# Here, we assume that the order in the log file is the same as the order in the environments

my @figenv = $texfile =~ /\\begin\{figure(\*?)\}/g;

my @sizes = $logfile =~ /(?<=Requested size:\s)([\d\.]+)pt\sx\s([\d\.]+)pt./g;
my @ars;
my @lengths;

for (my $i=0; $i <= $#images; $i++) {
	my $tmp = nearest(0.001, $sizes[2*$i] / $sizes[2*$i+1]);
	push(@ars,$tmp);
	if ($figenv[$i] eq '') { #The environment is plain \begin{figure}
		push(@lengths,ceil(150 / $tmp + 20));
	}
	elsif ($figenv[$i] eq '*') { # The environment is two column \begin{figure*}
		push(@lengths,ceil(300 / (0.5*$tmp) + 40));
	}
	else {
		die "Error while processing the figure environments";
	}
}

for ( @lengths ) {
    $imageswordcount += $_;
}

print "Images\n";
print "------\n";

if ( $#images > 0) {
	my $ml = max_length(@images);
	printf "%-${ml}s  Aspect ratio   Est. word count   Two-column\n", "File name";
	print "----------------------------------------------------------------------\n";
	
	for (my $i=0; $i <= $#images; $i++) {
		printf "%-${ml}s  %-13s  %s\t\t\t%s\n", $images[$i],$ars[$i],$lengths[$i],$figenv[$i];
	}
	print "\nTotal word count for images: $imageswordcount\n\n";
}
else {
	print "The file doesn't contain images.\n\n";
}

$totalcount += $imageswordcount;

print "Total word count (words + equations + images)\n$totalcount\n";

sub max_length {
    my $max = -1;
    my $max_ref;
    for (@_) {
        if (length > $max) {  # no temp variable, length() twice is faster
            $max = length;
            $max_ref = \$_;   # avoid any copying
        }
    }
    $max
}