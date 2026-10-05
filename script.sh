#!/bin/bash
cd openwrt

clone_retry() {
  local repo="$1"
  local target="$2"
  for attempt in 1 2 3; do
    git clone --depth 1 "$repo" "$target" && return 0
    rm -rf "$target"
    sleep 5
  done
  echo "Failed to clone $repo after 3 attempts" >&2
  return 1
}

# Add luci-app-adguardhome
clone_retry https://github.com/rufengsuixing/luci-app-adguardhome.git package-temp/luci-app-adguardhome
mv -f package-temp/luci-app-adguardhome package/lean/
rm -rf package-temp

# Add luci-theme-opentomcat
clone_retry https://github.com/Leo-Jo-My/luci-theme-opentomcat.git theme-temp/luci-theme-opentomcat
rm -rf theme-temp/luci-theme-opentomcat/LICENSE
rm -rf theme-temp/luci-theme-opentomcat/README.md
mv -f theme-temp/luci-theme-opentomcat package/lean/
rm -rf theme-temp

# Add luci-app-amlogic
clone_retry https://github.com/ophub/luci-app-amlogic.git package-temp/luci-app-amlogic
mv -f package-temp/luci-app-amlogic/luci-app-amlogic package/lean/
rm -rf package-temp
# Add AIC8800 USB Driver
# Add AIC8800 USB Driver
clone_retry https://github.com/shenmintao/aic8800d80.git package/aic8800

# Create OpenWrt Makefile for AIC8800
cat > package/aic8800/Makefile << 'EOF'
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=aic8800d80
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/aic8800d80
  SUBMENU:=Wireless Drivers
  TITLE:=AIC8800D80 WiFi driver
  DEPENDS:=+kmod-cfg80211 +kmod-mac80211 +kmod-usb-core
  FILES:=$(PKG_BUILD_DIR)/drivers/aic8800/aic8800_fdrv.ko $(PKG_BUILD_DIR)/drivers/aic8800/aic_load_fw.ko
  AUTOLOAD:=$(call AutoLoad,50,aic8800_fdrv aic_load_fw)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./drivers $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		M="$(PKG_BUILD_DIR)/drivers/aic8800" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		modules
endef

$(eval $(call KernelPackage,aic8800d80))
EOF

echo "CONFIG_PACKAGE_kmod-aic8800d80=y" >> .config
