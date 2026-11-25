# The file manager's data files: its registration as the desktop portal's
# file chooser, and the D-Bus activation that starts it for a request.
#
# SwiftPM builds the program; this installs it beside them when given:
#
#     swift build -c release --traits Native --product files
#     cmake -S Data -B .build/data -DCMAKE_INSTALL_PREFIX=/usr \
#         -DFILES_EXECUTABLE=$PWD/.build/release/files
#     cmake --install .build/data
#
# xdg-desktop-portal picks the backend by the desktop's portals.conf
# (swift-linux-shell's cacao-portals.conf), with
# org.freedesktop.impl.portal.FileChooser=cacao-files.

cmake_minimum_required(VERSION 3.16)
project(CoreAppsData NONE)

# Nothing here is a library, but GNUInstallDirs asks without a language.
set(CMAKE_INSTALL_LIBDIR lib CACHE PATH "Not used: no libraries are installed")
include(GNUInstallDirs)

set(FILES_EXECUTABLE "" CACHE FILEPATH "The built files program, to install as well")

configure_file(org.freedesktop.impl.portal.desktop.cacao.files.service.in
  ${CMAKE_CURRENT_BINARY_DIR}/org.freedesktop.impl.portal.desktop.cacao.files.service
  @ONLY)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/org.freedesktop.impl.portal.desktop.cacao.files.service
  DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services)
install(FILES
    cacao-files.portal
  DESTINATION ${CMAKE_INSTALL_DATADIR}/xdg-desktop-portal/portals)

if(FILES_EXECUTABLE)
  install(PROGRAMS ${FILES_EXECUTABLE} DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
