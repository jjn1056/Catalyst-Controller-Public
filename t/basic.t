use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::Most;
use Catalyst::Test 'MyApp';

{
  ok my $res = request '/favicon.ico';
  is $res->code, 200;
}

{
  ok my $res = request '/css/base.css';
  is $res->content, "css css css\n";
}

{
  ok my $res = request '/static/example.txt';
  is $res->content, "example\n";
}

{
  ok my $res = request '/static/css/base.css';
  is $res->content, "css css css\n";
}

{
  ok my $res = request '/onchain/base.css';
  is $res->content, "css css css\n";
}

done_testing;
