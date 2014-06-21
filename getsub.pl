#!/usr/bin/perl
use POSIX qw(ceil floor);
use File::Basename;
use Encode;
require Encode::Detect;
use base qw(Encode::Encoding);
use Encode qw(find_encoding);
use Encode::Detect::Detector;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use File::stat;
use Fcntl 'SEEK_SET';
use JSON;

&getSub($ARGV[0]);
&conv();
&moveTo($ARGV[0]);
#system("rm -rf /tmp/sub");


sub getSub{
	system("mkdir /tmp/sub");
	my $f = shift;
	my $file_size = stat($f)->size;
	my @md5 = ();
	open FILE, $f;
	binmode FILE;
	my @offset = ();
	$offset[0] = 4096;
	$offset[1] = floor ($file_size / 3) * 2;
	$offset[2] = floor ($file_size / 3);
	$offset[3] = $file_size - 8192;
	foreach my $o (@offset){
		my $part;
		sysseek FILE, $o, SEEK_SET;
		sysread FILE,$part,4096;
		push @md5, md5_hex($part);
	}
	my $ua = LWP::UserAgent->new;
	my $server_endpoint = "http://www.shooter.cn/api/subapi.php";
	my $req = POST( $server_endpoint, [
		'filehash' => join(';',@md5) ,
		'pathinfo' =>  basename($f),
		'format' => 'json',
		'lang' => 'Chn'
	]);

	$json = JSON->new->allow_nonref;
	my $resp = $ua->request($req);
	if ($resp->is_success) {
	    $message = $json->decode($resp->decoded_content);
	}
	$counter = 0;
	foreach my $j (@$message){
		$ext = $j->{'Files'}[0]->{'Ext'};
		$url = $j->{'Files'}[0]->{'Link'};
		$t = basename($f);
		$outname = "/tmp/sub/$t.$counter.$ext";
		#$print "wget --no-check-certificate -O $outname $url\n";
		system("wget -Y off --no-check-certificate -O $outname \"$url\" 2>/dev/null 1>/dev/null");
		$file_size = stat($outname)->size;
		if($file_size == 0) {next;}
		$counter++;
		$encoding = guess_encoding("$outname");
		$outname2 = "/tmp/sub/$t.$encoding.$ext";
		system("mv $outname $outname2");
	}

}

sub moveTo{
	$f = shift;
	($filename, $directories, $suffix) = fileparse($f);

	@filename_parts = split /\./,$filename;
	pop @filename_parts;
	$episode_name = join(".",@filename_parts);
	
	opendir ( DIR, "/tmp/sub") || die "Error in opendir";
	@files = grep {/\.(ssa|ass|aas|srt)$/} readdir(DIR) ;
	foreach $subname (@files){
		@subname_parts = split /\./,$subname;
		$s = $#subname_parts;
		$sub_name = join(".", ($episode_name, $subname_parts[$s-1], $subname_parts[$s] ));
		system("mv -f \"/tmp/sub/$subname\" \"$directories/$sub_name\"");
	}
	closedir DIR;

}

sub extract{
	$z = shift;
	system("mkdir /tmp/sub");

	#if($z=~m/\.rar$/){
	#	system("unrar e $z /tmp/sub");
	#}elsif($z=~m/\.zip$/){
	#	system("unzip $z -d /tmp/sub");
	#}else{
	#	system("tar xvf $z -C /tmp/sub");
	#}
	system("unar -no-directory -output-directory /tmp/sub $z");
	system("cd /tmp/sub; for i in `find . -type d|grep -v \"\\.\$\"`; do mv \$i/*.ass \$i/*.srt \$i/*.aas /tmp/sub/; done");
	system("rm -f /tmp/sub/*简体*");
	#system("rm -f /tmp/sub/*gb*");
	#system("rm -f /tmp/sub/*lol*");
}

sub guess_encoding{
	my $filename = shift;
	local $/=undef;
	open FILE, $filename or die "Couldn't open file: $!";
	$string = <FILE>;
	my $encoding = detect($string);
	if(!defined($encoding) || length($encoding) < 3){
		return "ISO8859-1";
	}else{
		return $encoding;
	}
}

sub conv{
	opendir ( DIR, "/tmp/sub") || die "Error in opendir";
	@files = grep {/\.(ass|aas|srt)$/} readdir(DIR) ;
	foreach $filename (@files){
		$encoding = uc(&guess_encoding("/tmp/sub/$filename"));
		if ($encoding=~/BIG/){
			$encoding = "BIG5-HKSCS";
		}
		print "Encoding ... $encoding\n";
		unless( !defined($encoding)){
			system("iconv -f $encoding -t utf-8 \"/tmp/sub/$filename\" > /tmp/sub/123");
		}
		system("mv -f  /tmp/sub/123 \"/tmp/sub/$filename\"");
	}
	closedir DIR;
}
