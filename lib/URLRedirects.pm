#!/usr/bin/perl
#
#   Mailcleaner - SMTP Antivirus/Antispam Gateway
#   Copyright (C) 2022 John Mertz <git@john.me.tz>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#   Library to decode URLs from URL scanning and Rewriting services.

package URLRedirects;

use strict;
use warnings;
use URI::Escape;

sub new
{
        my ($class, $args) = @_;
        my $self = $args;
        $self->{'services'} = getServices();
        return bless $self;
}

sub getServices
{
        # List of known rewriting services. Each requires a 'regex' for the URL input
        # pattern and a 'decoder' function which returns the decoded URL.
        my %services = (
                "ASP ReturnURL" => {
                        "regex"   => qr#/action/browser.asp\?returnUrl=#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#.*/action/browser.asp\?returnUrl=(.*)#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                },
                "Disqus" => {
                        "regex"   => qr#^disq.us/url\?url=#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#^disq.us/url\?url=([^*&]*)#$1#;
                                $url = uri_unescape($url);
                                $url =~ s#((?:https?://)?[^:]*):.*#$1#;
                                return $url;
                        }
                },
                "Google Redirect" => {
                        "regex"   => qr#(www|maps)\.google\.([a-z]{2,3}){1,2}/url\?q=#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#www\.google\.com/url\?q=(.*)#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                },
                "LinkedIn" => {
                        "regex" => qr%linkedin.com/slink\?code=([^#]+)%,
                        "decoder" => sub {
                                my $url = shift;
                                return head($url);
                        }
                },
                "Office 365" => {
                        "regex"   => qr#.*safelinks\.protection\.outlook\.com/\?url=#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#.*safelinks\.protection\.outlook\.com/\?url=(.*)#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                },
                "Proofpoint-v2" => {
                        "regex"   => qr#urldefense\.proofpoint\.com/v2#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s|\-|\%|g;
                                $url =~ s|_|\/|g;
                                $url = uri_unescape($url);
                                $url =~ s/^[^\?]*\?u=([^&]*)&.*$/$1/;
                                return $url;
                        }
                },
                "Proofpoint-v3" => {
                        "regex"   => qr#urldefense\.com/v3#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s|[^_]*__(.*)/__.*|$1|;
                                $url = uri_unescape($url);
                                $url =~ s/^[^\?]*\?u=([^&]*)&.*$/$1/;
                                return $url;
                        }
                },
                "Roaring Penguin" => {
                        "regex"   => qr#[^/]*/canit/urlproxy.php\?_q=[a-zA-Z0-9]+#,
                        "decoder" => sub {
                                use MIME::Base64;
                                my $url = shift;
                                $url =~ s|[^/]*/canit/urlproxy\.php\?_q\=([^&]*).*|$1|;
                                $url = uri_unescape($url) ;
                                $url = decode_base64($url);
                                return $url;
                        }
                },
                "SRVTRCK" => {
                        "regex"   => qr#(\w+\.)?srvtrck.com/v1/redirect\?#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#(?:\w+\.)?srvtrck.com/v1/redirect\?(?:.*&)?url=([^&]*).*#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                },
                "Trend Micro" => {
                        "regex"   => qr#[^\.]+\.trendmicro.com(?:\:443)?/wis/clicktime/v1/query\?url=#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#[^\.]+\.trendmicro.com(?:\:443)?/wis/clicktime/v1/query\?url=([^&]*).*#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                },
                "Twitter" => {
                        "regex"   => qr#twitter\.com\/i\/redirect\?url=([^&]*).*#,
                        "decoder" => sub {
                                my $url = shift;
                                $url =~ s#twitter\.com\/i\/redirect\?url=([^&]*).*#$1#;
                                $url = uri_unescape($url);
                                return $url;
                        }
                }
        );
        return \%services;
}

# The actual simple search and decode function
sub decode
{
        my $self = shift;
        my $url = shift;
        my $recursed = shift || 0;

        $url =~ s#^https?://##;
        foreach my $service (keys(%{$self->{'services'}})) {
                if ($url =~ $self->{'services'}->{$service}->{'regex'}) {
                        my $decoded = $self->{'services'}->{$service}->{'decoder'}($url);
                        if ($decoded) {
                                # Limit recursion to 10 steps
                                return $decoded if ($recursed == 10);
                                return $self->decode($decoded, ++$recursed);
                        } else {
                                return $url if ($recursed);
				return undef;
			}
                }
        }
        return $url if ($recursed);
        return 0;
}

sub head
{
        my $url = shift;

        use LWP::UserAgent;
        my $ua = LWP::UserAgent->new();
        $ua->max_redirect(0);

        my $head = $ua->head($url);
        return undef unless ($head->{_rc} == 301);
        return $head->{_headers}->{location};
}

1;
