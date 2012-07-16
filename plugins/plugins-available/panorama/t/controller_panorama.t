use strict;
use warnings;
use Test::More tests => 94;
use JSON::XS;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::panorama';
};

my $pages = [
    '/thruk/cgi-bin/panorama.cgi',
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Thruk Panorama',
    );
}

# json pages
$pages = [
    '/thruk/cgi-bin/panorama.cgi?task=stats_core_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_check_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=show_logs',
    '/thruk/cgi-bin/panorama.cgi?task=site_status',
    '/thruk/cgi-bin/panorama.cgi?task=hosts_pie',
    '/thruk/cgi-bin/panorama.cgi?task=services_pie',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman_grid',
    '/thruk/cgi-bin/panorama.cgi?task=pnp_graphs',
];

for my $url (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an array");
    ok(scalar keys %{$data} > 0, "json result has content");
}
