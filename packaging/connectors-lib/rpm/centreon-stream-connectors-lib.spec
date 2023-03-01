%{!?luaver: %global luaver %(lua -e "print(string.sub(_VERSION, 5))" || echo 0)}
%global luapkgdir %{_datadir}/lua/%{luaver}

Name:           centreon-stream-connectors-lib
Version:        3.6.0
Release:        1%{?dist}
Summary:        Centreon stream connectors lua modules

Group:          Applications/System
License:        Apache-2.0
URL:            https://www.centreon.com
Packager:       Centreon <contact@centreon.com>
Vendor:         Centreon Entreprise Server (CES) Repository, http://yum.centreon.com/standard/

Source0:        %{name}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

BuildRequires:  lua
BuildRequires:  lua-devel

Requires:       centreon-broker-core >= 22.04.0
Requires:       lua-socket >= 3.0
Requires:       lua-curl

%description
Those modules provides helpful methods to create stream connectors for Centreon

%prep
%setup -q -n %{name}

%build

%install
%{__install} -d $RPM_BUILD_ROOT%{luapkgdir}/centreon-stream-connectors-lib
%{__cp} -pr ./* $RPM_BUILD_ROOT%{luapkgdir}/centreon-stream-connectors-lib

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%{luapkgdir}/centreon-stream-connectors-lib

%changelog
