## Domain Registry Interface, .RO Domain EPP extension commands [https://epp2-test.rotld.ro/epp/index.html]
##
## Copyright (c) 2006-2013 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
## Copyright (c) 2014-2015 David Makuni <d.makuni@live.co.uk>. All rights reserved.
## Copyright (c) 2013-2015 Paulo Jorge <paullojorgge@gmail.com>. All rights reserved.
##
## This file is part of Net::DRI.
##
## Net::DRI is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## See the LICENSE file that comes with this distribution for more details.
####################################################################################################

package Net::DRI::Protocol::EPP::Extensions::RO::Domain;

use strict;
use warnings;

use Net::DRI::Exception;
use Net::DRI::Util;
use DateTime::Format::ISO8601;
use Net::DRI::Protocol::EPP::Util;
use Net::DRI::Data::Hosts;
use utf8;

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::RO::Domain - .RO EPP Domain extension commands for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

David Makuni <d.makuni@live.co.uk>

=head1 COPYRIGHT

Copyright (c) 2006-2013 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
Copyright (c) 2014-2015 David Makuni <d.makuni@live.co.uk>. All rights reserved.
Copyright (c) 2013-2015 Paulo Jorge <paullojorgge@gmail.com>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands {
	my ( $class, $version)=@_;
	my %tmp=(
		create =>               [ \&create, \&create_parse ],
		trade_request =>        [ \&trade_request, \&trade_request_parse ],
		trade_approve =>        [ \&trade_approve, undef ],
		trade_query =>          [ \&trade_query, \&trade_query_parse],
		transfer_request =>     [ \&transfer_request, undef ],
		transfer_cancel  =>     [ \&transfer_cancel, undef ],
		transfer_answer  =>     [ \&transfer_answer, undef ],
		transfer_query  =>      [ \&transfer_query, undef ],
		update =>               [ \&update, undef],
		info =>                 [ undef, \&info_parse],
		check =>                [ undef, \&check_parse]
	);

	return { 'domain' => \%tmp };
}

####################################################################################################

sub create {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	return unless ( (defined $rd->{'reserve_domain'}) || (defined $rd->{'domain_terms'}) );

	# Domain Password Validation
	Net::DRI::Exception::usererr_insufficient_parameters('auth-pw is required for .RO')
		unless ((defined $rd->{auth}->{pw}) && ($rd->{auth}->{pw} ne ''));
	Net::DRI::Exception::usererr_invalid_parameters('auth-pw supplied must have no spaces; one capital, small & special character with length between 6-40')
		unless ($rd->{auth}->{pw}=~ m/^[a-z0-9\-\.\,\:\;\[\]\{\}\_\+\=\@\#\$\^\*\?\!\|\~]{6,40}$/i);

	push @f,['rotld:agreement',{legal_use => $rd->{'domain_terms'}->{'legal_use'}, registration_rules => $rd->{'domain_terms'}->{'reg_rules'}}];
	if ($rd->{'reserve_domain'}->{'reserve'} == 1) {push @f,['rotld:reserve'];}

	push @e,['rotld:create',['rotld:domain',@f]];
	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub create_parse {
	my ($po,$otype,$oaction,$oname,$rinfo)=@_;
	my $mes=$po->message();
	return unless $mes->is_success();

	my $idndata=$mes->get_extension('idn','mapping');
	return unless defined $idndata;

	my $ns=$mes->ns('idn');
	$idndata=$idndata->getChildrenByTagNameNS($ns,'name');
	return unless $idndata->size();

	my $c=$idndata->shift->getFirstChild();
	while($c) {
		next unless ($c->nodeType() == 1); # element nodes ONLY
		my $name=$c->localname() || $c->nodeName();
		next unless $name && $c->getFirstChild();
		if ($name=~m/^(ace|unicode)$/) {
			$rinfo->{domain}->{$oname}->{$name}=$c->getFirstChild()->getData() if (defined $c);
		}
	} continue { $c=$c->getNextSibling(); }
	return;
}

sub trade_request {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	my @d=Net::DRI::Protocol::EPP::Util::domain_build_command($mes,['trade',{'op'=>'request'}],$domain);
	$mes->command_body(\@d);
	$mes->command([['trade',{'op'=>'request'}],'domain:trade',sprintf('xmlns:domain="%s" xsi:schemaLocation="%s %s"',$mes->nsattrs('domain'))]);

	push @f,['rotld:authorization_key', $rd->{'trade_auth_info'}->{'authorization_key'} ] if (defined $rd->{'trade_auth_info'}->{'authorization_key'});
	push @f,['rotld:c_registrant', $rd->{'trade_auth_info'}->{'c_registrant'} ] if (defined $rd->{'trade_auth_info'}->{'c_registrant'});
	push @f,['rotld:domain_password', $rd->{'trade_auth_info'}->{'domain_password'} ] if (defined $rd->{'trade_auth_info'}->{'domain_password'});
	push @e,['rotld:trade',['rotld:domain',['rotld:request',@f]]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub trade_request_parse {
	my ($po,$otype,$oaction,$oname,$rinfo)=@_;
	my $mes=$po->message();
	return unless $mes->is_success();

	my $trddata=$mes->get_extension('rotld','ext');
	return unless defined $trddata;

	my $ns=$mes->ns('rotld');
	$trddata=$trddata->getChildrenByTagNameNS($ns,'trdData');
	return unless $trddata->size();
	$trddata=$trddata->shift()->getChildrenByTagNameNS($ns,'domain');
	return unless $trddata->size();
	$trddata=$trddata->shift()->getChildrenByTagNameNS($ns,'request');
	return unless $trddata->size();

	my $c=$trddata->shift->getFirstChild();
	while($c) {
		next unless ($c->nodeType() == 1); # Element Nodes ONLY!
		my $name=$c->localname() || $c->nodeName();
		next unless $name && $c->getFirstChild();
		if ($name=~m/^(tid|authorization_key)$/) {
			$rinfo->{domain}->{$oname}->{$name}=$c->getFirstChild()->getData();
		}
	} continue { $c=$c->getNextSibling(); }
	return;
}

sub trade_approve {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	my @d=Net::DRI::Protocol::EPP::Util::domain_build_command($mes,['trade',{'op'=>'approve'}],$domain);
	$mes->command_body(\@d);
	$mes->command([['trade',{'op'=>'approve'}],'domain:trade',sprintf('xmlns:domain="%s" xsi:schemaLocation="%s %s"',$mes->nsattrs('domain'))]);

	return unless ((defined $rd->{'tid'}));

	push @f,['rotld:tid', $rd->{'tid'} ] if (defined $rd->{'tid'});
	push @e,['rotld:trade',['rotld:domain',['rotld:approve',@f]]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub trade_query {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	my @d=Net::DRI::Protocol::EPP::Util::domain_build_command($mes,['trade',{'op'=>'query'}],$domain);
	$mes->command_body(\@d);
	$mes->command([['trade',{'op'=>'query'}],'domain:trade',sprintf('xmlns:domain="%s" xsi:schemaLocation="%s %s"',$mes->nsattrs('domain'))]);

	return unless ((defined $rd->{'tid'}));

	push @f,['rotld:tid', $rd->{'tid'} ] if (defined $rd->{'tid'});
	push @e,['rotld:trade',['rotld:domain',['rotld:query',@f]]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub trade_query_parse {
	my ($po,$otype,$oaction,$oname,$rinfo)=@_;
	my $mes=$po->message();
	return unless $mes->is_success();

	my $trddata=$mes->get_extension('rotld','ext');
	return unless defined $trddata;

	my $ns=$mes->ns('rotld');
	$trddata=$trddata->getChildrenByTagNameNS($ns,'trdData');
	return unless $trddata->size();
	$trddata=$trddata->shift()->getChildrenByTagNameNS($ns,'domain');
	return unless $trddata->size();
	$trddata=$trddata->shift()->getChildrenByTagNameNS($ns,'query');
	return unless $trddata->size();

	my $c=$trddata->shift->getFirstChild();
	while($c) {
		next unless ($c->nodeType() == 1); # element nodes ONLY
		my $name=$c->localname() || $c->nodeName();
		next unless $name && $c->getFirstChild();
		if ($name=~m/^(registry_confirm|registrar_confirm|close_date|tid)$/) {
			$rinfo->{domain}->{$oname}->{$name}=$c->getFirstChild()->getData() if (defined $c);
		}
	} continue { $c=$c->getNextSibling(); }
	return;
}

sub transfer_request {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	return unless ((defined $rd->{'authorization_key'}));

	push @f,['rotld:authorization_key', $rd->{'authorization_key'} ] if (defined $rd->{'authorization_key'});
	push @e,['rotld:transfer',['rotld:domain',@f]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub transfer_answer {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f,$op);

	return unless ((defined $rd->{'authorization_key'}));

	push @f,['rotld:authorization_key', $rd->{'authorization_key'} ] if (defined $rd->{'authorization_key'});
	push @e,['rotld:transfer',['rotld:domain',@f]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub transfer_cancel {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	return unless ((defined $rd->{'authorization_key'}));

	push @f,['rotld:authorization_key', $rd->{'authorization_key'} ] if (defined $rd->{'authorization_key'});
	push @e,['rotld:transfer',['rotld:domain',@f]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub transfer_query {
	my ($epp,$domain,$rd)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	return unless ((defined $rd->{'authorization_key'}));

	push @f,['rotld:authorization_key', $rd->{'authorization_key'} ] if (defined $rd->{'authorization_key'});
	push @e,['rotld:transfer',['rotld:domain',@f]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub update {
	my ($epp,$domain,$todo)=@_;
	my $mes=$epp->message();
	my (@e,@f);

	if (!$todo->add('ns') || ($todo->add('ns') && $todo->add('ns')->is_empty()) ) {
		Net::DRI::Exception::usererr_insufficient_parameters('force_empty_ns flag required to update nameservers for .RO') unless Net::DRI::Util::xml_parse_boolean($todo->add('force_empty_ns'));
	}

	return unless ( (defined $todo->set('activate_domain')) && ($todo->set('activate_domain')=~m/^(1)$/));
	push @e,['rotld:update',['rotld:domain',['rotld:activate']]];

	my $eid = $mes->command_extension_register('rotld','ext');
	$mes->command_extension($eid,\@e);
	return;
}

sub info_parse {
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $idndata=$mes->get_extension('idn','mapping');
 return unless defined $idndata;

 my $ns=$mes->ns('idn');
 $idndata=$idndata->getChildrenByTagNameNS($ns,'name');
 return unless $idndata->size();

 my $c=$idndata->shift->getFirstChild();
 while($c) {
	 next unless ($c->nodeType() == 1); # element nodes ONLY
	 my $name=$c->localname() || $c->nodeName();
	 next unless $name && $c->getFirstChild();
	 if ($name=~m/^(ace|unicode)$/) {
		 $rinfo->{domain}->{$oname}->{$name}=$c->getFirstChild()->getData() if (defined $c);
	 }
 } continue { $c=$c->getNextSibling(); }
 return;
}

sub check_parse {
	my ($po,$otype,$oaction,$oname,$rinfo)=@_;
	my $mes=$po->message();
	return unless $mes->is_success();
	my $msg = {};

	# IDN & Domain Renew Availability Extension(s)
	my $idndata=$mes->get_extension('idn','mapping');
	my $trddata=$mes->get_extension('rotld','ext');
	return unless ((defined $idndata) || (defined $trddata));

	if (defined $idndata) {
		my $ns=$mes->ns('idn');
		$idndata=$idndata->getChildrenByTagNameNS($ns,'name');
		if ($idndata->size()) {
			my $c=$idndata->shift->getFirstChild();
			while($c) {
				next unless ($c->nodeType() == 1); # element nodes ONLY
				my $name=$c->localname() || $c->nodeName();
				next unless $name && $c->getFirstChild();
				if ($name=~m/^(ace|unicode)$/) {
					$rinfo->{domain}->{$oname}->{$name}=$c->getFirstChild()->getData() if (defined $c);
				}
			} continue { $c=$c->getNextSibling(); }
		}
	}

	if (defined $trddata) {
		foreach my $el (Net::DRI::Util::xml_list_children($trddata)) {
			my ($name,$c)=@$el;
				if ($name eq 'check_renew_availability') {
					$msg->{renewable} = $c->getAttribute('renewable') if $c->hasAttribute('renewable');
				}
		}
		my $ns=$mes->ns('rotld');
		$trddata=$trddata->getChildrenByTagNameNS($ns,'check_renew_availability');
		if ($trddata->size()) {
			my $c=$trddata->shift->getFirstChild();
			while($c) {
				next unless ($c->nodeType() == 1); # element nodes ONLY
				my $name=$c->localname() || $c->nodeName();
				next unless $name && $c->getFirstChild();
				if ($name=~m/^(reason|name)$/) {
					$msg->{reason} = $c->getFirstChild()->getData() if (defined $c);
				}
			} continue { $c=$c->getNextSibling(); }
			$rinfo->{domain}->{$oname}->{renew_availability} = $msg;
		}
	}
	return;
}

####################################################################################################
1;
