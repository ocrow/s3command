#!/usr/bin/perl -w

use strict;
use Test::More tests => 27;
use Data::UUID;
use File::Copy;

my $ug = new Data::UUID;

sub find_item {
    my ($command, $item) = @_;
    my $found = 0;
    open CF, "$command |"
        or die "Couldn't read from S3 '$command'";
    while (my $line = <CF>) {
        chomp $line;
        $found = 1 if ($line eq $item);
    }
    close CF;
    return $found;
}

sub read_file_list {
    # get the long format file listing line for file $item
    my ($bucket, $item) = @_;
    my $cmd = "./s3 ll $bucket";
    open LL, "$cmd |" or die "Couldn't read from S3 '$cmd'";
    my @result;
    while (my $line = <LL>) {
        chomp $line;
        my @fields = split " ", $line;
        if ($fields[3] eq $item) {
            if (@result) {
                diag("Same file found twice");
                return;
            } else {
                @result = @fields;
            }
        }
    }
    close LL;
    # return (size, datestamp, filename), where datestamp eq "<date> <time>"
    if (@result) {
        return ($result[0], "$result[1] $result[2]", $result[3]);
    }
}

my ($bucket, $status, $found, $result, @fields, @lines);
my $path = "test_path";
my $test_file = "test_file1";
my $test_data = "Test Data\n";
my $test2_data = "Mochi Ice\n";

# write to test file
open TF, ">$test_file"
    or BAIL_OUT("Couldn't write to test file '$test_file'");
print TF $test_data;
close TF;

ok (-r $test_file, "Test file created");

$status = system("./s3 ls >/dev/null");
ok ($status == 0, "List buckets");

if ($status > 0) { BAIL_OUT("Couldn't connect to S3"); }

$bucket = $ug->to_string($ug->create);

$status = system("./s3 mkbucket $bucket");
ok($status == 0, "Make a bucket");

$found = find_item("./s3 ls", $bucket);
ok($found == 1, "Locate test bucket");

$status = system("./s3 put $bucket/$path $test_file");
ok ($status == 0, "Put file to S3");

$found = find_item("./s3 ls $bucket/$path", $test_file);
ok ($found == 1, "Find file in S3");

my @list1 = read_file_list("$bucket/$path", $test_file);
ok ($list1[2] eq $test_file, "File list contains test file");
ok ($list1[0] == length($test_data), 
    "File list reports correct file length");

my %info;
open INFO, "./s3 info $bucket/$path $test_file|";
while (<INFO>) {
    chomp;
    my ($key, $value) = split ": ";
    $info{$key} = $value;
}
close INFO;
ok ($info{'content_length'} == length($test_data), 
    "Read info content length");

$status = system("./s3 push $bucket/$path $test_file");
ok (($status >> 8) == 2, "Push unchanged file to S3");

my @list2 = read_file_list("$bucket/$path", $test_file);
ok ($list2[0] == length($test_data), "Size unchanged");
ok ($list2[1] eq $list1[1], "Modified date unchanged");

$result = `./s3 diff $bucket/$path $test_file 2>&1`;
ok ($? == 0, "File unchanged on server");

open TF, ">$test_file"
    or BAIL_OUT("Couldn't write to test file '$test_file'");
print TF $test2_data;
close TF;

$result = `./s3 diff $bucket/$path $test_file 2>&1`;
ok ($? != 0, "File changed on server");

$status = system("./s3 push $bucket/$path $test_file");
ok ($status == 0, "Push changed file to S3");

my @list3 = read_file_list("$bucket/$path", $test_file);
ok ($list3[0] == length($test2_data), "Size unchanged");
ok ($list3[1] ne $list2[1], "Modified date now changed");

unlink $test_file;
ok (! -e $test_file, "Delete test file locally");

$status = system("./s3 get $bucket/$path $test_file");
ok ($status == 0, "Get file from S3");

ok (-r $test_file, "Retrieved file is readable");

open TF, $test_file
    or BAIL_OUT("Couldn't read test file '$test_file'");
@lines = <TF>;
close TF;

ok (scalar(@lines) == 1, "Retrieved file is one line long");
ok ($lines[0] eq $test2_data, "Retrieved file contains correct data");


$status = system("./s3 rm $bucket/$path $test_file");
ok ($status == 0, "Remove test file from S3");

$found = find_item("./s3 ls $bucket/$path", $test_file);
ok ($found == 0, "Test file removed");

unlink $test_file;
ok (! -e $test_file, "Local test file removed");

$status = system("./s3 rmbucket $bucket");
ok ($status == 0, "Remove a bucket");

$found = find_item("./s3 ls", $bucket);
ok($found == 0, "Test bucket removed");


