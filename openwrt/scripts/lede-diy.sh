#!/bin/bash -e

#######OprX的相关优化#######
#一、定义克隆功能函数
#第一种
#git clone -b 分支 --single-branch 仓库地址 到本地目录（如：package/文件名 #文件名不能相同）
#cd  package/文件名  #主注意目录级别（此处为二级，退出为cd ../..  一级：./diydata  退出为 cd ..  三级 package/文件名1/文件名2 退出为cd ../../..）
#git sparse-checkout init --cone 
#git sparse-checkout set 目标文件  #可以一级或者二级，三级，多个目录用空格隔开。注意是连上级目录一起。
#cd ../..  #退出本地目录（）

#第二种  来源https://github.com/Jejz168/OpenWrt
mkdir package/new
function merge_package() {
	# 参数1是分支名,参数2是库地址,参数3是所有文件下载到指定路径。
	# 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
	# 示例:
	# merge_package 分支 仓库地址 下载到指定路径(已存在或者自定义) 目标文件（多个空格分开）
	# 下载到不存在的目录时: rm -rf package/new; mkdir package/new
	# merge_package master https://github.com/WYC-2020/openwrt-packages package/openwrt-packages luci-app-eqos luci-app-openclash luci-app-ddnsto ddnsto 
	# merge_package master https://github.com/lisaac/luci-app-dockerman package/lean applications/luci-app-dockerman #结果是将luci-app-dockerman放在package/lean下
	# merge_package main https://github.com/linkease/nas-packages-luci package/new luci/luci-app-ddnsto  #结果是package/new/luci-app-ddnsto
	# merge_package master https://github.com/linkease/nas-packages package/new network/services/ddnsto  #结果是package/new/ddnsto 
	# merge_package master https://github.com/coolsnowwolf/lede package/kernel package/kernel/mac80211  #将目标仓库的package/kernel/mac80211克隆到本地package/kernel下
	#merge_package main https://github.com/Lienol/openwrt.git  ./tools tools/ucl tools/upx  #表示在根目录生成一个tools文件夹。本来就会有，所以报错。
    #merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl tools/upx  #表示目标目录tool下的ucl和upx移动到根目录已经存在的tools文件夹。
	if [[ $# -lt 3 ]]; then
		echo "Syntax error: [$#] [$*]" >&2
		return 1
	fi
	trap 'rm -rf "$tmpdir"' EXIT
	branch="$1" curl="$2" target_dir="$3" && shift 3
	rootdir="$PWD"
	localdir="$target_dir"
	[ -d "$localdir" ] || mkdir -p "$localdir"
	tmpdir="$(mktemp -d)" || exit 1
        echo "开始下载：$(echo $curl | awk -F '/' '{print $(NF)}')"
	git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
	cd "$tmpdir"
	git sparse-checkout init --cone
	git sparse-checkout set "$@"
	# 使用循环逐个移动文件夹
	for folder in "$@"; do
		mv -f "$folder" "$rootdir/$localdir"
	done
	cd "$rootdir"
}

#二、导入自己data目录数据配置 （注意结果是./diydata/openwrt/data）
#git clone -b main --single-branch https://github.com/ilxp/eS_lede_build_script.git ./diydata
#cd  ./diydata
#git sparse-checkout init --cone 
#git sparse-checkout set openwrt/data
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ..

#相关配置文件	
#cp -rf ./diydata/openwrt/data/files ./package/base-files/
#cp -rf ./diydata/openwrt/data/files  files
#自定义app
#cp -rf ./diydata/openwrt/data/app/*  ./
#初始化文件

merge_package main https://github.com/ilxp/eS_lede_build_script ./diydata openwrt/data   #注意结果是./diydata/data）

#相关配置文件	
cp -rf ./diydata/data/files ./package/base-files/
#cp -rf ./diydata/data/files  files
#自定义app
cp -rf ./diydata/data/app/*  ./

#初始化文件
#克隆default-settings
cp -f ./diydata/data/default-settings-eS-lede package/lean/default-settings/files/zzz-default-settings

#三、编译出错的########
rm -rf feeds/packages/mosdns  #新版不再支持lede
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/libs/libpfring
rm -rf package/wwan/app/luci-app-pcimodem
rm -rf package/wwan/app/luci-app-spdmodem
rm -rf package/lean/mentohust
rm -rf ./feeds/packages/utils/v2dat
###################

#四、系统优化########
# 1、kenrel Vermagic
# kenrel Vermagic  即 01-prepare_base-mainline.sh中的代码
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
#grep HASH include/kernel-6.6 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic
grep HASH include/kernel-$kernel_version | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 2、Optimization level -Ofast
#sed -i 's/Os/O2/g' include/target.mk
sed -i 's/Os/O2 -march=x86-64-v2/g' include/target.mk

# 3、Fix x86 - CONFIG_ALL_KMODS
sed -i 's/hwmon, +PACKAGE_kmod-thermal:kmod-thermal/hwmon/g' package/kernel/linux/modules/hwmon.mk

# 3、固件版本(21.3.2 %y : 年份的最后两位数字)
#date=`TZ=UTC-8 date +%y.%1m.%1d`
#R$(TZ=UTC-8 date +'%y.%-m.%-d')
ReV_Date=`TZ=UTC-8 date +%y.%-m.%-d`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$ReV_Date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk
sed -i "s/DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='OprX eS%C Built By ilxp'/g" package/base-files/files/etc/openwrt_release

# 4、img编译时间前缀。
#sed -i 's/IMG_PREFIX:=/IMG_PREFIX:=$(shell date +%Y%m%d)-oprx-2203-/g' include/image.mk
#sed -i 's/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)/IMG_PREFIX:=$(shell date +%Y%m%d)-oprx/g' include/image.mk  #在编译的时候统一改名字
#去掉版本号 openwrt-23.05.2-x86-64或者openwrt-23.05-snapshot-r0-60e49cf-x86-64改为openwrt-x86-64
sed -i 's/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)-/g' include/image.mk
sed -i 's/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)/IMG_PREFIX:=$(shell date +%m.%d.%Y)-oprx-eS/g' include/image.mk

#Compile_Date=$(TZ=UTC-8 date +'%Y%m%d')
#FW_VERSION="${Compile_Date}-oprx-eS${ReV_Date}"
#sed -i "s/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)/IMG_PREFIX:=$FW_VERSION/g" include/image.mk

# 5、修改登陆ip以及主机名
sed -i "s/192.168.1.1/192.168.8.1/" package/base-files/files/bin/config_generate
sed -i "s/OpenWrt/OprX/g" package/base-files/files/bin/config_generate
# 修改主机名openwrt为OprX （将系统所有包含openwrt改为oprx，慎用）
#sed -i "s/OpenWrt/OprX/g" package/base-files/files/bin/config_generate package/base-files/image-config.in config/Config-images.in Config.in include/u-boot.mk include/version.mk package/network/config/wifi-scripts/files/lib/wifi/mac80211.sh || true

# 6、内核版本（尽量不要修改，好komd）
#sed -i 's/KERNEL_PATCHVER:=6.1/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# 7、网络连接数
#sed -i 's/net.netfilter.nf_conntrack_max=16384/net.netfilter.nf_conntrack_max=65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
echo -e "\nnet.netfilter.nf_conntrack_max=65535" >> package/kernel/linux/files/sysctl-nf-conntrack.conf

# 8、修复依赖
sed -i 's/PKG_HASH.*/PKG_HASH:=skip/' feeds/packages/utils/containerd/Makefile

# 8、Fix mt76 wireless driver
pushd package/kernel/mt76
sed -i '/mt7662u_rom_patch.bin/a\\techo mt76-usb disable_usb_sg=1 > $\(1\)\/etc\/modules.d\/mt76-usb' Makefile
popd

# 9、kiddin9大神的####for openwrt
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf
#for X—86
sed -i 's/kmod-r8169/kmod-r8168/' target/linux/x86/image/64.mk

# 10、Jejz168大神优化===for lede
# 设置密码为空（安装固件时无需密码登陆，然后自己修改想要的密码）
#sed -i '/$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF./d' package/lean/default-settings/files/zzz-default-settings

# 调整 x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改版本号
#sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings

# 设置ttyd免帐号登录
sed -i 's/\/bin\/login/\/bin\/login -f root/' feeds/packages/utils/ttyd/files/ttyd.config

# 默认 shell 为 bash
sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd

# samba解除root限制
sed -i 's/invalid users = root/#&/g' feeds/packages/net/samba4/files/smb.conf.template

# coremark跑分定时清除
sed -i '/\* \* \* \/etc\/coremark.sh/d' feeds/packages/utils/coremark/*

##切换为samba4
#sed -i 's/luci-app-samba/luci-app-samba4/g' package/lean/autosamba/Makefile

# 显示增加编译时间
#sed -i "s/<%=pcdata(ver.distname)%> <%=pcdata(ver.distversion)%>/<%=pcdata(ver.distname)%> <%=pcdata(ver.distversion)%> (By @Jejz build $(TZ=UTC-8 date "+%Y-%m-%d %H:%M"))/g" package/lean/autocore/files/x86/index.htm

# 修改概览里时间显示为中文数字
sed -i 's/os.date()/os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")/g' package/lean/autocore/files/x86/index.htm
sed -i 's/os.date("%c")/os.date("%Y-%m-%d %H:%M:%S")/g' package/feeds/luci/luci-mod-admin-full/luasrc/controller/admin/system.lua

# 修改欢迎banner
#cp -f $GITHUB_WORKSPACE/personal/banner package/base-files/files/etc/banner
# wget -O ./package/base-files/files/etc/banner https://raw.githubusercontent.com/Jejz168/OpenWrt/main/personal/banner

# 固件更新地址
#sed -i '/CPU usage/a\                <tr><td width="33%"><%:Compile update%></td><td><a target="_blank" href="https://github.com/Jejz168/OpenWrt/releases">👆查看</a></td></tr>'  package/lean/autocore/files/x86/index.htm
#cat >>feeds/luci/modules/luci-base/po/zh-cn/base.po<<- EOF

#msgid "Compile update"
#msgstr "固件地址"
#EOF

#udpxy汉化      
cp -f ./diydata/data/udpxy.lua ./feeds/luci/applications/luci-app-udpxy/luasrc/model/cbi
cp -f ./diydata/data/udpxy.js ./feeds/luci/applications/luci-app-udpxy/htdocs/luci-static/resources/view
#1）添加编译作者-开源致谢
#sed -i '/<tr><td width="33%"><%:CPU usage/a <tr><td width="33%"><%:Compiler author%></td><td>ZuiFengGuai</td></tr>' package/lean/autocore/files/x86/index.htm
sed -i '/<tr><td width="33%"><%:CPU usage/a <tr><td width="33%"><%:Thanks Contribution%></td><td><a target="_blank" href="https://github.com/coolsnowwolf/lede/">欢迎使用OprX-eS系列,感谢Lean大雕对OpenWrt的开源贡献！</a></td></tr>' package/lean/autocore/files/x86/index.htm

#添加汉化
sed -i '5a\msgid "Thanks Contribution"' feeds/luci/modules/luci-base/po/zh-cn/base.po
#sed -i '6a\msgstr "编译作者"' feeds/luci/modules/luci-base/po/zh-cn/base.po
sed -i '6a\msgstr "开源致谢"' feeds/luci/modules/luci-base/po/zh-cn/base.po
sed -i '7a \\' feeds/luci/modules/luci-base/po/zh-cn/base.po

#2）添加赞助地址
sed -i '/<tr><td width="33%"><%:Thanks Contribution/a <tr><td width="33%"><%:Firmware Update%></td><td><a target="_blank" href="https://afdian.com/a/ioprx/plan">赞助我会做得更好！</a></td></tr>' package/lean/autocore/files/x86/index.htm
#sed -i '/<tr><td width="33%"><%:Thanks Contribution/a <tr><td width="33%"><%:Firmware Update%></td><td>在TTYD终端--输入tools--输入u-选择对应操作即可</td></tr>' package/lean/autocore/files/x86/index.htm

#添加汉化
sed -i '8a\msgid "Firmware Update"' feeds/luci/modules/luci-base/po/zh-cn/base.po
sed -i '9a\msgstr "为爱发电"' feeds/luci/modules/luci-base/po/zh-cn/base.po
sed -i '10a \\' feeds/luci/modules/luci-base/po/zh-cn/base.po

# 修正部分从第三方仓库拉取的软件 Makefile 路径问题
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/include\ \.\.\/\.\.\/luci\.mk/include \$(TOPDIR)\/feeds\/luci\/luci\.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/include\ \.\.\/\.\.\/lang\/golang\/golang\-package\.mk/include \$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang\-package\.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=\@GHREPO/PKG_SOURCE_URL:=https:\/\/github\.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=\@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload\.github\.com/g' {}

# 11、ecrasy大神diy===
#fix.sh的：
# fix stupid coremark benchmark error
touch package/base-files/files/etc/bench.log
chmod 0666 package/base-files/files/etc/bench.log
echo "Touch coremark log file to fix uhttpd error!!!"

# make minidlna depends on libffmpeg-full instead of libffmpeg
# little bro ffmpeg mini custom be gone
sed -i "s/libffmpeg /libffmpeg-full /g" feeds/packages/multimedia/minidlna/Makefile
echo "Set minidlna depends on libffmpeg-full instead of libffmpeg"

# remove ipv6-helper depends on odhcpd*
sed -i "s/+odhcpd-ipv6only//g" package/lean/ipv6-helper/Makefile
echo "Remove ipv6-helper depends on odhcpd*"

# make luci-app-firewall depends on uci-firewall instead of firewall  #导致无法编译成功
#sed -i 's/+firewall/+uci-firewall/g' feeds/luci/applications/luci-app-firewall/Makefile
#echo "Set luci-app-firewall depends on uci-firewall instead of firewall"

#diy.sh的：
# Replace fgrep with grep -F in /etc/profile
sed -i 's/fgrep -sq/grep -Fsq/g' package/base-files/files/etc/profile
echo "Replace fgrep with grep -F in /etc/profile"

# Add model.sh to remove annoying board name for Intel J4125
cp ./diydata/data/model.sh package/base-files/files/etc/
chmod 0755 package/base-files/files/etc/model.sh
echo "Add model.sh"

# Add 92-ula-prefix, try to set up IPv6 ula prefix after wlan up
# and call model.sh
mkdir -p package/base-files/files/etc/hotplug.d/iface
cp ./diydata/data/92-ula-prefix package/base-files/files/etc/hotplug.d/iface/
chmod 0755 package/base-files/files/etc/hotplug.d/iface/92-ula-prefix
echo "Add 92-ula-prefix"

# set v2raya depends on v2ray-core
sed -i "s/xray-core/v2ray-core/g" feeds/packages/net/v2raya/Makefile
sed -i "s/xray-core/v2ray-core/g" feeds/luci/applications/luci-app-v2raya/Makefile
echo "set v2raya depends on v2ray-core"
##=====以上来源ecrasy大神========================================================

# 12、骷髅头大神的https://github.com/DHDAXCW/OpenWRT_x86_x64/blob/main/scripts/lean.sh====
# 更换golang版本
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 23.x feeds/packages/lang/golang

# Mod zzz-default-settings
#pushd package/lean/default-settings/files
#sed -i '/http/d' zzz-default-settings
#sed -i '/18.06/d' zzz-default-settings
#export orig_version=$(cat "zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
#export date_version=$(date -d "$(rdate -n -4 -p ntp.aliyun.com)" +'%Y-%m-%d')
#sed -i "s/${orig_version}/${orig_version} (${date_version})/g" zzz-default-settings
#popd

# 更换 libssh libmbim
rm -rf packages/libs/libssh
rm -rf packages/libs/libmbim
#merge_package master https://github.com/openwrt/packages.git package/new libs/libssh libs/libmbim
merge_package main https://github.com/DHDAXCW/dhdaxcw-app package/new libmbim lame

# dhcp
sed -i 's/100/6/g' package/network/services/dnsmasq/files/dhcp.conf
sed -i 's/150/200/g' package/network/services/dnsmasq/files/dhcp.conf
#=============== 以上来源骷髅头大神================

###############二、相关luci应用#############################
#一）、主题
#1）argon主题（lede分支适合lean的lede是luci18）
rm -rf feeds/luci/themes/luci-theme-argon
git clone -b master https://github.com/jerrykuku/luci-theme-argon.git package/diy/luci-theme-argon

#2）修改 argon 为默认主题
sed -i '/set luci.main.mediaurlbase=\/luci-static\/bootstrap/d' feeds/luci/themes/luci-theme-bootstrap/root/etc/uci-defaults/30_luci-theme-bootstrap
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' ./feeds/luci/collections/luci/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci-nginx/Makefile

#二）、翻墙系列（lede编译系统自带为SSR-Plus）
#1、ssr-plus
rm -rf package/helloworld
rm -rf feeds/luci/applications/luci-app-ssr-plus
#git clone https://github.com/fw876/helloworld.git package/helloworld 采用sbwml的

#采用kenzok8的small库
#git clone https://github.com/kenzok8/small.git package/helloworld

# sbwml的SSRP & Passwall
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
git clone https://github.com/sbwml/openwrt_helloworld package/helloworld -b v5

##FQ全部调到VPN菜单
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/model/cbi/shadowsocksr/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/view/shadowsocksr/*.htm

#解决缺乏libopenssl-legacy依赖
#sed -i 's/ +libopenssl-legacy//g' package/helloworld/shadowsocksr-libev/Makefile

#2、passwall
#克隆官方的
#rm -rf feeds/luci/applications/luci-app-passwall
#git clone -b main https://github.com/xiaorouji/openwrt-passwall-packages.git package/diy/openwrt-passwall-packages
#git clone -b main https://github.com/xiaorouji/openwrt-passwall.git  package/diy/openwrt-passwall
# passwall
#merge_package main https://github.com/xiaorouji/openwrt-passwall package/custom luci-app-passwall

#采用kenzok8的small库
#git clone https://github.com/kenzok8/small.git package/diy/openwrt-passwall

##FQ全部调到VPN菜单
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/controller/*.lua
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/passwall/*.lua
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/*.lua
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/model/cbi/passwall/server/*.lua
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/app_update/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/socks_auto_switch/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/global/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/haproxy/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/log/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/node_list/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/rule/*.htm
#sed -i 's/services/vpn/g' package/diy/openwrt-passwall/luci-app-passwall/luasrc/view/passwall/server/*.htm
# Passwall 白名单
#echo '
#teamviewer.com
#epicgames.com
#dangdang.com
#account.synology.com
#ddns.synology.com
#checkip.synology.com
#checkip.dyndns.org
#checkipv6.synology.com
#ntp.aliyun.com
#cn.ntp.org.cn
#ntp.ntsc.ac.cn
#' >>./package/diy/openwrt-passwall/luci-app-passwall/root/usr/share/passwall/rules/direct_host

#3、clash（不编译luci，只编译带内核）
#1）openclash
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/helloworld/luci-app-openclash
#sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git' feeds.conf.default
#注意master对应core打分master的分支，dev对应core的dev，
git clone -b master --single-branch https://github.com/vernesong/OpenClash.git  package/diy/openclash
# 添加内核（新版只支持meta内核）
wget https://github.com/vernesong/OpenClash/raw/core/master/meta/clash-linux-amd64.tar.gz&&tar -zxvf *.tar.gz
chmod 0755 clash
rm -rf *.tar.gz&&mkdir -p package/base-files/files/etc/openclash/core&&mv clash package/base-files/files/etc/openclash/core/clash_meta
##FQ全部调到VPN菜单
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/model/cbi/openclash/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/view/openclash/*.htm

# DHDAXCW骷髅头的preset-clash-core.sh
#mkdir -p package/base-files/files/etc/openclash/core
#CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-${1}.tar.gz"
#CLASH_TUN_URL=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/contents/master/premium\?ref\=core | grep download_url | grep $1 | awk -F '"' '{print $4}' | grep -v "v3" )
#CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${1}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
#wget -qO- $CLASH_DEV_URL | tar xOvz > package/base-files/files/etc/openclash/core/clash
#wget -qO- $CLASH_TUN_URL | gunzip -c > package/base-files/files/etc/openclash/core/clash_tun
#wget -qO- $CLASH_META_URL | tar xOvz > package/base-files/files/etc/openclash/core/clash_meta
wget -qO- $GEOIP_URL > package/base-files/files/etc/openclash/GeoIP.dat
#wget -qO- $GEOSITE_URL > package/base-files/files/etc/openclash/GeoSite.dat #提示已经存在，无法编译
chmod +x package/base-files/files/etc/openclash/core/clash*

# 4、mihomo（只支持firewall4.lede无望）
#git clone --depth=1 https://github.com/morytyann/OpenWrt-mihomo package/luci-app-mihomo

# 5、homeproxy（只支持firewall4.lede无望）
#git clone --depth=1 https://github.com/muink/luci-app-homeproxy.git package/diy/luci-app-homeproxy
#git clone --depth=1 https://github.com/immortalwrt/homeproxy.git package/diy/luci-app-homeproxy
#rm -rf ./feeds/packages/net/sing-box
#依赖组件
#git clone -b v5 --single-branch https://github.com/sbwml/openwrt_helloworld.git   package/homeproxy
#cd package/homeproxy
#git sparse-checkout init --cone 
#git sparse-checkout set chinadns-ng sing-box
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

#merge_package v5 https://github.com/sbwml/openwrt_helloworld.git package/new chinadns-ng sing-box

#三）、应用商店
#git clone https://github.com/linkease/nas-packages.git  package/diy/nas-packages
#git clone https://github.com/linkease/nas-packages-luci.git  package/diy/nas-packages-luci
git clone https://github.com/linkease/istore.git  package/diy/istore
git clone https://github.com/linkease/istore-ui.git  package/diy/istore-ui

#四）、sirpdboy大神的相关插件
#中文netdata
rm -rf feeds/luci/applications/luci-app-netdata
git clone https://github.com/sirpdboy/luci-app-netdata.git package/diy/luci-app-netdata

#网络设置向导
git clone https://github.com/sirpdboy/luci-app-netwizard.git package/diy/luci-app-netwizard
sed -i 's/Inital Setup/设置向导/g' package/diy/luci-app-netwizard/luasrc/controller/netwizard.lua

#网络速度测试
git clone https://github.com/sirpdboy/netspeedtest.git package/diy/netspeedtest
sed -i 's/Net Speedtest/网络测速/g' package/diy/netspeedtest/luci-app-netspeedtest/luasrc/controller/netspeedtest.lua

#定时设置
git clone https://github.com/sirpdboy/luci-app-autotimeset package/diy/luci-app-autotimeset
sed -i 's/Scheduled Setting/定时设置/g' package/diy/luci-app-autotimeset/luasrc/controller/autotimeset.lua

#关机  编译不成功采用esir的
#git clone https://github.com/sirpdboy/luci-app-poweroffdevice package/diy/luci-app-poweroffdevice
#关机 poweroff（esir大神）
git clone https://github.com/esirplayground/luci-app-poweroff package/diy/luci-app-poweroff
sed -i 's/PowerOff/关机/g' package/diy/luci-app-poweroff/luasrc/controller/poweroff.lua

#家长控制
git clone https://github.com/sirpdboy/luci-app-parentcontrol package/diy/luci-app-parentcontrol
sed -i 's/Parent Control/家长控制/g' package/diy/luci-app-parentcontrol/luasrc/controller/parentcontrol.lua
sed -i 's/Control/管控/g' package/diy/luci-app-parentcontrol/luasrc/controller/parentcontrol.lua

#自动扩容分区
git clone https://github.com/sirpdboy/luci-app-partexp package/diy/luci-app-partexp
sed -i 's/Partition Expansion/分区扩容/g' package/diy/luci-app-partexp/luasrc/controller/partexp.lua
rm -rf package/diy/luci-app-partexp/po/zh_Hans
sed -i 's, - !, -o !,g' package/diy/luci-app-partexp/root/etc/init.d/partexp
sed -i 's,expquit 1 ,#expquit 1 ,g' package/diy/luci-app-partexp/root/etc/init.d/partexp

#ddns-go
git clone https://github.com/sirpdboy/luci-app-ddns-go package/diy/luci-app-ddns-go

#高级设置
git clone https://github.com/sirpdboy/luci-app-advanced.git package/diy/luci-app-advanced
#rm -rf package/diy/luci-app-advanced/htdocs #不能删除

##五）QOS相关
#石像鬼qos采用我自己的，会有一个QOS栏目生成
#git clone -b openwrt-luci18 https://github.com/ilxp/gargoyle-qos-openwrt.git  package/diy/gargoyle-qos-openwrt #官方qos-gargoyle 在lede上无法安装成功。

#2）eqos，采用luci自带的即可。把eqos放在管控下。不在列入Qos目录下
#rm -rf feeds/luci/applications/luci-app-eqos #lean库里没有eqos
#sed -i 's/network/QOS/g' feeds/luci/applications/luci-app-eqos/luasrc/controller/eqos.lua #将其移动到QOS或者control管控下
#git clone https://github.com/ilxp/luci-app-eqos.git  package/diy/luci-app-eqos  #我的会产生一个QOS栏目
#svn co https://github.com/kiddin9/openwrt-packages/trunk/eqos-master-wiwiz package/diy/luci-app-eqos
#sed -i 's/network/control/g' package/diy/luci-app-eqos/luasrc/controller/eqos.lua
#sed -i 's/EQoS/网速控制/g' package/diy/luci-app-eqos/luasrc/controller/eqos.lua
git clone https://github.com/sirpdboy/luci-app-eqosplus  package/diy/luci-app-eqosplus

#nft-qos
#rm -rf feeds/packages/net/nft-qos
#rm -rf feeds/luci/applications/luci-app-nft-qos
#git clone https://github.com/ilxp/openwrt-nft-qos.git  package/diy/openwrt-nft-qos
#merge_package master https://github.com/ilxp/openwrt-nft-qos.gi package/new luci-app-nft-qos nft-qos
#sed -i 's/services/qos/g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua   #将其移动到QOS目录下

#3)SQM
#sed -i 's/network/qos/g' feeds/luci/applications/luci-app-sqm/luasrc/controller/sqm.lua   #将其移动到QOS下
# SQM Translation
mkdir -p feeds/packages/net/sqm-scripts/patches
#curl -s https://init2.cooluc.com/openwrt/patch/sqm/001-help-translation.patch > feeds/packages/net/sqm-scripts/patches/001-help-translation.patch
cp -f ./diydata/data/sqm/001-help-translation.patch  feeds/packages/net/sqm-scripts/patches/001-help-translation.patch

#六）、DNS相关（lede带smartdns）
#1）smartdns（18.06是lede的branch，master分支安装尊贵不上）
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/applications/luci-app-smartdns
git clone -b master https://github.com/pymumu/luci-app-smartdns.git package/diy/luci-app-smartdns
git clone https://github.com/pymumu/openwrt-smartdns.git package/diy/smartdns

mkdir -p package/base-files/files/etc/smartdns
#中国域名列表
#下载三个最新列表合并到cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt"  >> package/base-files/files/etc/smartdns/cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-datt@release/apple-cn.txt"    >> package/base-files/files/etc/smartdns/cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt"   >> package/base-files/files/etc/smartdns/cn.conf
#去除full regexp并指定china组解析
sed "s/^full://g;s/^regexp:.*$//g;s/^/nameserver \//g;s/$/\/cn/g" -i package/base-files/files/etc/smartdns/cn.conf
chmod +x package/base-files/files/etc/smartdns/cn.conf

#广告域名列表
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/reject-list.txt"  >> package/base-files/files/etc/smartdns/block.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/win-spy.txt"  >> package/base-files/files/etc/smartdns/block.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/win-extra.txt"  >> package/base-files/files/etc/smartdns/block.conf
sed "s/^full://g;s/^regexp:.*$//g;s/^/address \//g;s/$/\/#/g" -i package/base-files/files/etc/smartdns/block.conf
chmod +x package/base-files/files/etc/smartdns/block.conf

#2）mosdns 不支持lede了的luci18
#rm -rf feeds/packages/net/mosdns
#rm -rf feeds/luci/applications/luci-app-mosdns
#rm -rf feeds/packages/net/v2ray-geodata
#git clone -b v5 --single-branch https://github.com/sbwml/luci-app-mosdns package/diy/luci-app-mosdns #需要v2ray-geodata依赖
#git clone -b master --single-branch https://github.com/QiuSimons/openwrt-mos  package/diy/openwrt-mos  #自带mosdns以及v2ray-geodata

#七、广告过滤
#1）adguardhome带核心安装。
rm -rf feeds/packages/net/adguardhome
rm -rf feeds/luci/applications/luci-app-adguardhome
rm -rf package/new/luci-app-adguardhome

#git clone -b master --single-branch https://github.com/Hyy2001X/AutoBuild-Packages.git   package/adguardhome
#cd package/adguardhome
#git sparse-checkout init --cone 
#git sparse-checkout set luci-app-adguardhome
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

merge_package master https://github.com/Hyy2001X/AutoBuild-Packages.git package/new luci-app-adguardhome


#git clone -b main --single-branch https://github.com/kiddin9/kwrt-packages.git   package/kiddin
#cd package/kiddin
#git sparse-checkout init --cone 
#git sparse-checkout set adguardhome r8101 luci-app-openvpn-server
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..
#sed -i 's/services/vpn/g' package/kiddin/luci-app-openvpn-server/luasrc/controller/openvpn-server.lua

#merge_package main https://github.com/kiddin9/kwrt-packages.gitt package/new adguardhome r8101 luci-app-openvpn-server

#git clone -b master --single-branch https://github.com/kiddin9/openwrt-adguardhome package/diy/openwrt-adguardhome #编译不成功

# 添加内核
#v0.107.X内核
latest_version="$(curl -s https://github.com/AdguardTeam/AdGuardHome/tags | grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" | sed -n '/[0-9][0-9]/p' | sed -n 1p | sed 's/.tar.gz//g')"

#v0.108.X内核，api里面没有v0.107.
#latest_version="$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/tags | grep -Eo "v0.108.0-b.+[0-9\.]" | head -n 1)"
#解压缩
wget https://github.com/AdguardTeam/AdGuardHome/releases/download/${latest_version}/AdGuardHome_linux_amd64.tar.gz&&tar -zxvf *.tar.gz
chmod 0755 AdGuardHome
chmod 0755 AdGuardHome/AdGuardHome
rm -rf *.tar.gz&&mkdir -p package/base-files/files/usr/bin&&mv AdGuardHome/AdGuardHome package/base-files/files/usr/bin/ #软件包安装，不能带核心0.108，否则不能成功

#2）ikoolproxy与openssl
#由于openssl从1.1.1升级到了3.0.10导致ikoolproxy无法下载证书。故只能退回。https://github.com/coolsnowwolf/lede/commit/7494eb16185a176de226f55e842cadf94f1c5a11
#rm -rf package/libs/openssl
#rm -rf include/openssl-module.mk
#w版本
#git clone -b main --single-branch https://github.com/ilxp/opensslw.git  package/libs/openssl

#ikoolproxy文件
#git clone -b main --single-branch https://github.com/ilxp/luci-app-ikoolproxy.git package/diy/luci-app-ikoolproxy
#cd package/diy/luci-app-ikoolproxy
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../../..

#merge_package main https://github.com/ilxp/luci-app-ikoolproxy.git package/new luci-app-ikoolproxy
git clone -b main --single-branch https://github.com/ilxp/luci-app-ikoolproxy.git package/diy/luci-app-ikoolproxy


#3）dnsfilter过滤广告kiddin9大神
#git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter package/diy/luci-app-dnsfilter

#七、管控相关
#1） APP 过滤
#git clone -b master --depth 1 https://github.com/destan19/OpenAppFilter.git package/diy/OpenAppFilter
#sed -i 's/services/control/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

git clone -b master --depth 1 https://github.com/sbwml/OpenAppFilter.git  package/diy/OpenAppFilter
sed -i 's/network/control/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#更新特征库
pushd package/diy/OpenAppFilter
#wget -qO - https://github.com/QiuSimons/OpenAppFilter-destan19/commit/9088cc2.patch | patch -p1
#wget https://www.openappfilter.com/assets/feature/feature2.0_cn_23.07.29.cfg -O ./open-app-filter/files/feature.cfg
wget https://github.com/ilxp/oaf/raw/main/feature2.0_cn_24.6.26.cfg -O ./open-app-filter/files/feature.cfg
popd
#翻译应用过滤
sed -i 's/App Filter/应用过滤/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#2、管控
rm -rf feeds/luci/applications/luci-app-control-webrestriction
rm -rf feeds/luci/applications/luci-app-control-timewol
rm -rf feeds/luci/applications/luci-app-control-weburl
rm -rf feeds/luci/applications/luci-app-timecontrol
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-openvpn-server  #采用lienol的，会生成一个vpn的栏目

#网络唤醒plus
#git clone -b master --single-branch https://github.com/zxlhhyccc/bf-package-master.git   package/wolplus
#cd package/wolplus
#git sparse-checkout init --cone 
#git sparse-checkout set zxlhhyccc/luci-app-wolplus
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

merge_package master https://github.com/zxlhhyccc/bf-package-master.git package/new zxlhhyccc/luci-app-wolplus

#lienol大神的管控\文件浏览器
#git clone -b main --single-branch https://github.com/Lienol/openwrt-package.git   package/lienol
#cd package/lienol
#git sparse-checkout init --cone 
#git sparse-checkout set luci-app-control-webrestriction luci-app-control-weburl luci-app-timecontrol luci-app-control-timewol luci-app-filebrowser luci-app-openvpn-server
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..
#sed -i 's/Control/管控/g' package/lienol/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-control-weburl/luasrc/controller/weburl.lua
#sed -i 's/Internet Time Control/上网时间控制/g' package/lienol/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-control-timewol/luasrc/controller/timewol.lua
#sed -i 's/File Browser/文件浏览器/g' package/lienol/luci-app-filebrowser/luasrc/controller/filebrowser.lua

merge_package main https://github.com/Lienol/openwrt-package.git package/new luci-app-control-webrestriction luci-app-control-weburl luci-app-timecontrol luci-app-control-timewol luci-app-filebrowser luci-app-openvpn-server
sed -i 's/Access Control/访问限制/g' package/new/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
sed -i 's/Control/管控/g' package/new/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
sed -i 's/Control/管控/g' package/new/luci-app-control-weburl/luasrc/controller/weburl.lua
sed -i 's/Internet Time Control/上网时间控制/g' package/new/luci-app-timecontrol/luasrc/controller/timecontrol.lua
sed -i 's/Control/管控/g' package/new/luci-app-timecontrol/luasrc/controller/timecontrol.lua
sed -i 's/Control/管控/g' package/new/luci-app-control-timewol/luasrc/controller/timewol.lua
sed -i 's/File Browser/文件浏览器/g' package/new/luci-app-filebrowser/luasrc/controller/filebrowser.lua

#八、其他luci-app
#1、turboacc去dns
rm -rf feeds/luci/applications/luci-app-turboacc
#git clone -b master --single-branch https://github.com/xiangfeidexiaohuo/openwrt-packages.git   package/turboacc
#cd package/turboacc
#git sparse-checkout init --cone 
#git sparse-checkout set luci-app-turboacc
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

merge_package master https://github.com/xiangfeidexiaohuo/openwrt-packages.git package/new patch/luci-app-turboacc


#2、京东签到 By Jerrykuku 作者已关闭了
#git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
#git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus

#3、网易云音乐解锁
#git clone -b js --depth 1 https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/diy/luci-app-unblockneteasemusic
#sed -i 's/解除网易云音乐播放限制/网易云音乐解锁/g' package/diy/luci-app-unblockneteasemusic/root/usr/share/luci/menu.d/luci-app-unblockneteasemusic.json
#for lede
git clone --branch master https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/diy/luci-app-unblockneteasemusic
sed -i 's/解除网易云音乐播放限制/网易云音乐解锁/g' package/diy/luci-app-unblockneteasemusic/luasrc/controller/unblockneteasemusic.lua
sed -i 's, +node,,g' package/diy/luci-app-unblockneteasemusic/Makefile
pushd package/diy/luci-app-unblockneteasemusic
    wget -qO - https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic/commit/a880428.patch | patch -p1
popd

#4、filebrowser文件浏览器
#rm -rf feeds/luci/applications/luci-app-filebrowser
# filebrowser 文件浏览器
#merge_package main https://github.com/Lienol/openwrt-package package/custom luci-app-filebrowser
#sed -i 's/File Browser/文件浏览器/g' package/diy/luci-app-filebrowser/luasrc/controller/filebrowser.lua

#5、流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon

#6、zerotier
#rm -Rf feeds/luci/applications/luci-app-zerotier
#git clone https://github.com/rufengsuixing/luci-app-zerotier package/diy/luci-app-zerotier

#7、终端ZSH工具
mkdir -p package/base-files/files/root
pushd package/base-files/files/root
## Install oh-my-zsh
# Clone oh-my-zsh repository
git clone https://github.com/ohmyzsh/ohmyzsh ./.oh-my-zsh
# Install extra plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions
# Get .zshrc dotfile
#cp -f ./diydata/data/zsh/.zshrc .
popd
cp -f ./diydata/data/zsh/.zshrc ./package/base-files/files/root/

# DHDAXCW骷髅头的preset-terminal-tools.sh
#mkdir -p files/root
#pushd files/root
## Install oh-my-zsh
# Clone oh-my-zsh repository
#git clone https://github.com/ohmyzsh/ohmyzsh ./.oh-my-zsh
# Install extra plugins
#git clone https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
#git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
#git clone https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions
# Get .zshrc dotfile
#cp ./diydata/data/zsh/.zshrc .
#popd

# Change default shell to zsh将系统ash改为zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd
sed -i 's/\/bin\/bash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

#8、# Docker 容器 
rm -rf feeds/luci/applications/luci-app-dockerman
#git clone -b master --single-branch https://github.com/lisaac/luci-app-dockerman.git   package/dockerman
#cd package/dockerman
#git sparse-checkout init --cone 
#git sparse-checkout set applications/luci-app-dockerman
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

rm -rf feeds/luci/collections/luci-lib-docker
#git clone -b master --single-branch https://github.com/lisaac/luci-lib-docker.git   package/dockerlib
#cd package/dockerlib
#git sparse-checkout init --cone 
#git sparse-checkout set collections/luci-lib-docker
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

#sed -i '/auto_start/d' package/dockerman/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman

merge_package master https://github.com/lisaac/luci-app-dockerman.git package/new applications/luci-app-dockerman
merge_package master https://github.com/lisaac/luci-lib-docker.git package/new collections/luci-lib-docker
#sed -i '/auto_start/d' package/new/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman  #死活启动不了

pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/e2e5ee69.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/pull/20054.patch | patch -p1
popd
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile

#9、全能推送（商店自己安装）
#rm -rf feeds/luci/applications/luci-app-pushbot
#git clone https://github.com/zzsj0928/luci-app-pushbot.git package/diy/luci-app-pushbot

#10、相关驱动
# NIC driver - R8168 & R8125 & R8152 & R8101
git clone https://github.com/sbwml/package_kernel_r8168 package/kernel/r8168
git clone https://github.com/sbwml/package_kernel_r8152 package/kernel/r8152
git clone https://github.com/sbwml/package_kernel_r8101 package/kernel/r8101
git clone https://github.com/sbwml/package_kernel_r8125 package/kernel/r8125

#11、alist
#rm -rf feeds/packages/lang/golang
#git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone --depth=1 -b lua https://github.com/sbwml/luci-app-alist package/alist
# merge_package master https://github.com/sbwml/luci-app-alist package/new alist

#12、diskman
#rm -Rf package/new/luci-app-diskman
#git clone -b master --single-branch https://github.com/lisaac/luci-app-diskman.git   package/diskm
#cd package/diskm
#git sparse-checkout init --cone 
#git sparse-checkout set applications/luci-app-diskman
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..

merge_package master https://github.com/lisaac/luci-app-diskman.git package/new applications/luci-app-diskman

#13、lan口设置  不能在workflow上打。（yaof上能打成功patch，sbwml上不成功）
#rm -rf target/linux/x86/base-files/etc/board.d/02_network  #清除系统自带的02，需要lede的才能patche成功。
#wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/x86/base-files/etc/board.d/02_network -P target/linux/x86/base-files/etc/board.d/
patch -p1 <./diydata/data/patches/def_set_interfaces_lan_wan.patch

#14、chatgpt
#git clone --depth=1 https://github.com/sirpdboy/luci-app-chatgpt-web package/luci-app-chatgpt

#15、在线升级（通过对链接的前缀10.16.2024进行比较大小进行升级）
#原地址：https://github.com/ilxp/builder/releases/download/firmware/10.16.2024-OprX-x86-64-generic-squashfs-combined-efi.img.gz
#原地址：https://github.com/ilxp/builder/releases/download/firmware/vermd5.txt  其中firmware为固定的tag名称。在Release发布的时候注意。
git clone https://github.com/ilxp/openwrt-gpsysupgrade-kiddin9  package/new/openwrt-gpsysupgrade
#改仓库名builder
sed -i "s/builder/oprx-builder/g" package/new/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
#改vermd5名称：
sed -i "s/vermd5/vermd5-eS/g" package/new/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
#改固件
sed -i "s/oprx/oprx-eS/g" package/new/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
#改后的地址：https://github.com/ilxp/oprx-builder/releases/download/firmware/10.16.2024-oprx-es-x86-64-generic-squashfs-combined-efi.img.gz
#改后的地址：https://github.com/ilxp/oprx-builder/releases/download/firmware/vermd5-eS.txt  #对应固件分类。


#2）autoupdate
#git clone -b main --single-branch https://github.com/ilxp/openwrt-autoupdate.git  package/new/openwrt-autoupdate
#cd package/diy/openwrt-autoupdate
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../../..

#修改内容
#1）固件标签
#sed -i "s/TARGET_FLAG=Std/TARGET_FLAG=Std/g" package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#2）版本号：需要固定成：R24.1.1-20240101
#Version_Date="R$(TZ=UTC-8 date +'%y.%-m.%-d')-" 
#Compile_Date=$(TZ=UTC-8 date +'%Y%m%d')
#OP_VERSION="${Version_Date}${Compile_Date}"
#sed -i "s/OP_VERSION=R24.1.1-20240101/OP_VERSION=$OP_VERSION/g" package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default  #使用双引号

#date2=`TZ=UTC-8 date +%Y%m%d`
##sed -i "s/R24.1.1-20240101/Snapshot-$date2/g" package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default  #使用双引号
#3）源码作者
#sed -i 's/OP_AUTHOR=openwrt/OP_AUTHOR=coolsnowwolf/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#4）项目名
#sed -i 's/OP_REPO=openwrt/OP_REPO=lede/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#5）项目分支
#sed -i 's/OP_BRANCH=main/OP_BRANCH=master/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default

# 16、移动栏目
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json
#for lede
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua

#12、更换 Nodejs 版本
rm -rf feeds/packages/lang/node
git clone https://github.com/sbwml/feeds_packages_lang_node-prebuilt -b packages-23.05 feeds/packages/lang/node
#rm -rf ./feeds/packages/lang/node
#merge_package master https://github.com/QiuSimons/OpenWrt-Add  package/custom  feeds_packages_lang_node-prebuilt
#cp -rf ../package/custom/feeds_packages_lang_node-prebuilt ./feeds/packages/lang/node

#13、相关引擎
# Shortcut Forwarding Engine
#git clone https://git.cooluc.com/sbwml/shortcut-fe package/new/shortcut-fe
# FullCone module
#git clone https://git.cooluc.com/sbwml/nft-fullcone package/new/nft-fullcone
# IPv6 NAT
#git clone https://github.com/sbwml/packages_new_nat6 package/new/nat6
# natflow
#git clone https://github.com/sbwml/package_new_natflow package/new/natflow
# iptables-mod-fullconenat for firewall3
#git clone https://github.com/sbwml/fullconenat package/new/nft-fullcone

#14、sbwml大神的优化for23.05
# x86 - disable intel_pstate & mitigations
sed -i 's/noinitrd/noinitrd intel_pstate=disable mitigations=off/g' target/linux/x86/image/grub-efi.cfg
# openssl -Ofast
sed -i "s/-O3/-Ofast/g" package/libs/openssl/Makefile
# procps-ng - top
sed -i 's/enable-skill/enable-skill --disable-modern-top/g' feeds/packages/utils/procps-ng/Makefile
# opkg  #lede无法使用。已删
#mkdir -p package/system/opkg/patches
#cp -rf ./diydata/data/patches/900-opkg-download-disable-hsts.patch ./package/system/opkg/patches/

# TTYD
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i '3 a\\t\t"order": 50,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init

#15、autocore
#git clone --depth 1 https://github.com/sbwml/autocore-arm  package/system/autocore
#sed -i '/init/d' package/system/autocore/Makefile
#sed -i '/autocore.json/a\\	$(INSTALL_BIN) ./files/x86/autocore $(1)/etc/init.d/' package/system/autocore/Makefile
#sed -i '/autocore.json/a\\	$(INSTALL_DIR) $(1)/etc/init.d' package/system/autocore/Makefile
#cp -rf ./diydata/data/autocore  package/system/autocore/files/x86/

#16、 samba4 - bump version
rm -rf feeds/packages/net/samba4
git clone https://github.com/sbwml/feeds_packages_net_samba4 feeds/packages/net/samba4
# liburing - 2.7 (samba-4.21.0)
rm -rf feeds/packages/libs/liburing
git clone https://github.com/sbwml/feeds_packages_libs_liburing feeds/packages/libs/liburing
# enable multi-channel
sed -i '/workgroup/a \\n\t## enable multi-channel' feeds/packages/net/samba4/files/smb.conf.template
sed -i '/enable multi-channel/a \\tserver multi channel support = yes' feeds/packages/net/samba4/files/smb.conf.template
# default config
sed -i 's/#aio read size = 0/aio read size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#aio write size = 0/aio write size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/bind interfaces only = yes/bind interfaces only = no/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#create mask/create mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#directory mask/directory mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/0666/0644/g;s/0744/0755/g;s/0777/0755/g' feeds/luci/applications/luci-app-samba4/htdocs/luci-static/resources/view/samba4.js
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/samba.config
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/smb.conf.template

#17、USB 打印机与KMS 激活助手  #USB 打印机 会产生一个nas项目
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new openwrt_pkgs/luci-app-usb-printer

#18、KMS 激活助手
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/luci-app-vlmcsd
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/vlmcsd

#19、 清理内存
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/luci-app-ramfree

#20、 OLED 驱动程序
git clone -b master --depth 1 https://github.com/NateLol/luci-app-oled.git package/new/luci-app-oled

#21、 natmap
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/luci-app-natmapt.git package/luci-app-natmapt
pushd package/luci-app-natmapt
umask 022
git checkout
popd
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/openwrt-natmapt.git package/natmapt
pushd package/natmapt
umask 022
git checkout
popd
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/openwrt-stuntman.git package/stuntman
pushd package/stuntman
umask 022
git checkout
popd

#21、 uwsgi
sed -i 's,procd_set_param stderr 1,procd_set_param stderr 0,g' feeds/packages/net/uwsgi/files/uwsgi.init
sed -i 's,buffer-size = 10000,buffer-size = 131072,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's,logger = luci,#logger = luci,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# rpcd
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js

# 22、UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
##merge_package main https://github.com/Lienol/openwrt.git  ./tools tools/ucl tools/upx  #表示在根目录生成一个tools文件夹。本来就会有，所以报错。
#merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl tools/upx  #表示在移动到根目录已经存在的tools文件夹。lienol版本有点旧3.95。
merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl
merge_package main https://github.com/ilxp/upx-openwrt.git tools upx   #最新版4.2.4

# v2raya
git clone --depth 1 https://github.com/zxlhhyccc/luci-app-v2raya.git package/new/luci-app-v2raya
rm -rf ./feeds/packages/net/v2raya
merge_package master https://github.com/openwrt/packages.git package/new net/v2raya

##########################################################################