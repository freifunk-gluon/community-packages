include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-dnsmasq-dhcp-relay
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-dnsmasq-dhcp-relay
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+gluon-core +gluon-client-bridge +gluon-dnsmasq
	TITLE:=DHCP relay for the client network
endef

define Package/ffgraz-dnsmasq-dhcp-relay/description
	Relays client DHCP into one server in the mesh, instead of serving the
	client network from the node the way ddhcpd does.
endef

$(eval $(call BuildPackageGluon,ffgraz-dnsmasq-dhcp-relay))
