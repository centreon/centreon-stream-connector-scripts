Name:           %{PACKAGE_NAME}
Version:        %{VERSION}
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

Requires:       centreon-stream-connectors-lib >= %{MIN_LIB_VERSION}

%description
Those modules provides helpful methods to create stream connectors for Centreon

%prep
%setup -q -n %{name}

%build

%install
%{__install} -d $RPM_BUILD_ROOT%{_datadir}/centreon-broker/lua
%{__cp} -pr ./*.lua $RPM_BUILD_ROOT%{_datadir}/centreon-broker/lua

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files

%changelog
