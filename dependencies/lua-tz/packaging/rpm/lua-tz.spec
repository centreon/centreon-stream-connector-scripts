%{!?luaver: %global luaver %(lua -e "print(string.sub(_VERSION, 5))" || echo 0)}
%global luapkgdir %{_datadir}/lua/%{luaver}
%global lualibdir %{_libdir}/lua/%{luaver}
%global debug_package %{nil}

Name:           lua-tz
Version:        %{VERSION}
Release:        1%{?dist}
Summary:        lua tz

Group:          Applications/System
License:        Apache-2.0
URL:            https://www.centreon.com
Packager:       Centreon <contact@centreon.com>
Vendor:         Centreon Entreprise Server (CES) Repository, http://yum.centreon.com/standard/

Source0:        %{name}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:  lua
BuildRequires:  lua-devel

Requires:       lua

%description
lua tz library

%prep
%setup -q -n %{name}

%build

%install
%{__install} -d $RPM_BUILD_ROOT%{luapkgdir}/luatz
%{__cp} -p ./* $RPM_BUILD_ROOT%{luapkgdir}/luatz

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%{luapkgdir}/luatz

%changelog
