#!/bin/bash
awk '
/GENERATE_INFOPLIST_FILE = YES;/ {
    print $0;
    print "\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"核心功能需要访问本地网络以允许同局域网设备远程控制提词器。\";"
    print "\t\t\t\tINFOPLIST_KEY_NSBonjourServices = ("
    print "\t\t\t\t\t\"_http._tcp\","
    print "\t\t\t\t);"
    next;
}
{ print $0; }
' ticiqi.xcodeproj/project.pbxproj > tmp.pbxproj
mv tmp.pbxproj ticiqi.xcodeproj/project.pbxproj
