include $(TOPDIR)/rules.mk

PKG_NAME:=uqmi-amplr
PKG_RELEASE:=0.12
PKG_VERSION:=2024-06-24

PKG_MAINTAINER:=Matti Laakso <malaakso@elisanet.fi> and Maarten Van Hoecke <maarten@amplr.be>

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_PARALLEL:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/uqmi-amplr
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=WWAN
	DEPENDS:=+libubox +libblobmsg-json +kmod-usb-net +kmod-usb-net-qmi-wwan +wwan
	TITLE:=Control utility for mobile broadband modems, mod by mrhaav and adapted by Maarten for amplr
endef

define Package/uqmi-amplr/description
	uqmi is a command line tool for controlling mobile broadband modems using
	the QMI-protocol.
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-ffunction-sections \
	-fdata-sections \
	-Wno-error=dangling-pointer \
	-Wno-error=maybe-uninitialized

TARGET_LDFLAGS += -Wl,--gc-sections

CMAKE_OPTIONS += \
	-DDEBUG=1 \
	-DDEBUG_PACKET=0

define Package/uqmi-amplr/install
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uqmi $(1)/sbin/

	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/lib/netifd/proto/qmi.sh $(1)/lib/netifd/proto

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/uqmi_d.sh $(1)/usr/bin

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/uqmi_d $(1)/etc/init.d
endef

$(eval $(call BuildPackage,uqmi-amplr))
