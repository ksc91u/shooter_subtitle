#!/opt/local/bin/perl
use POSIX qw(ceil floor);
use File::Basename;
require Encode::Detect;
use base qw(Encode::Encoding);
use Encode qw(find_encoding);
use Encode::Detect::Detector;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use File::stat;
use File::Copy;
use Fcntl 'SEEK_SET';
use JSON;
use File::Path qw(rmtree);

&getSub($ARGV[0]);
&conv();
&moveTo($ARGV[0]);
rmtree("/tmp/sub");


sub getSub{
	mkdir("/tmp/sub");
	my $f = shift;
	my($filename, $directories, $suffix) = fileparse($f);
	$filename =~ /(.*)\..*?/;
	$filename = $1;
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
	    eval {
	    	$message = $json->decode($resp->decoded_content);
	    };
	}
	$counter = 0;
	foreach my $j (@$message){
		$ext = $j->{'Files'}[0]->{'Ext'};
		$url = $j->{'Files'}[0]->{'Link'};
		print "$url\n";
		$outname = "/tmp/sub/$t.$counter.$ext";
		system("wget -Y off -O $outname \"$url\" 2>/dev/null 1>/dev/null");
		$file_size = stat($outname)->size;
		if($file_size == 0) {next;}

		$counter++;
		$encoding = my_guess_encoding("$outname");
		$outname2 = "/tmp/sub/$filename.$ext";
		if (-e $outname2) {
			$outname2 = "/tmp/sub/$filename.$encoding.$ext";
		} 
		print "$outname2\n";
		move($outname,$outname2);
	}

}

sub moveTo{
	$f = shift;
	($filename, $directories, $suffix) = fileparse($f);

	
	opendir ( DIR, "/tmp/sub") || die "Error in opendir";
	@files = grep {/\.(ssa|ass|aas|srt)$/} readdir(DIR) ;
	foreach $subname (@files){
		move("/tmp/sub/$subname", "$directories/");
        system("chmod -R a+w $directories");
	}
	closedir DIR;

}

sub my_guess_encoding{
	my $filename = shift;
	local $/=undef;
	open FILE, $filename or die "Couldn't open file: $!";
	$string = <FILE>;
	my $encoding = detect($string);
	if(!defined($encoding) || length($encoding) < 3){
		#$encoding = guess_encoding($string, qw/big5 euc-cn utf-8 utf-16 utf-32/);
		return "UTF-16LE";
	}else{
		if ($encoding=~/BIG/){
			$encoding = "BIG5-HKSCS";
		}
		if ($encoding=~/GB/){
			$encoding = "GB18030";
		}
		if ($encoding=~/CYRILLIC/i){
			$encoding = "MACCYRILLIC";
		}
		return $encoding;
	}
}

sub conv{
	opendir ( DIR, "/tmp/sub") || die "Error in opendir";
	@files = grep {/\.(ass|aas|srt)$/} readdir(DIR) ;
	foreach $filename (@files){
		$srcfile = "/tmp/sub/$filename";
		$encoding = uc(&my_guess_encoding($srcfile));
		print "Encoding ... $encoding\n";
		unless( !defined($encoding)){
			$r = system("/usr/bin/iconv -f $encoding -t UTF-8 \"$srcfile\" > /tmp/sub/123");
		}
		if($r == 0) {
			move("/tmp/sub/123",$srcfile);
		}
	}
	closedir DIR;
}
