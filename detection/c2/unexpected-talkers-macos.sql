-- Unexpected programs communicating over HTTPS (state-based)
--
-- references:
--   * https://attack.mitre.org/techniques/T1071/ (C&C, Application Layer Protocol)
--
-- tags: transient state net often
-- platform: macos
SELECT
  pos.protocol,
  pos.local_port,
  pos.remote_port,
  pos.remote_address,
  pos.local_port,
  pos.local_address,
  CONCAT (
    MIN(p0.euid, 500),
    ',',
    pos.protocol,
    ',',
    MIN(pos.remote_port, 32768),
    ',',
    REGEX_MATCH (p0.path, '.*/(.*?)$', 1),
    ',',
    p0.name,
    ',',
    s.authority,
    ',',
    s.identifier
  ) AS exception_key,
  CONCAT (
    MIN(p0.euid, 500),
    ',',
    pos.protocol,
    ',',
    MIN(pos.remote_port, 32768),
    ',',
    REGEX_MATCH (p0.path, '.*/(.*?)$', 1),
    ',',
    p0.name,
    ',',
    MIN(f.uid, 500),
    'u,',
    MIN(f.gid, 500),
    'g'
  ) AS alt_exception_key,
  CONCAT (s.authority, ',', s.identifier) AS id_exception_key,
  -- Child
  p0.pid AS p0_pid,
  p0.path AS p0_path,
  s.authority AS p0_sauth,
  s.identifier AS p0_sid,
  p0.name AS p0_name,
  p0.cmdline AS p0_cmd,
  p0.cwd AS p0_cwd,
  p0.euid AS p0_euid,
  p0_hash.sha256 AS p0_sha256,
  -- Parent
  p0.parent AS p1_pid,
  p1.path AS p1_path,
  p1.name AS p1_name,
  p1.euid AS p1_euid,
  p1.cmdline AS p1_cmd,
  p1_hash.sha256 AS p1_sha256,
  -- Grandparent
  p1.parent AS p2_pid,
  p2.name AS p2_name,
  p2.path AS p2_path,
  p2.cmdline AS p2_cmd,
  p2_hash.sha256 AS p2_sha256
FROM
  process_open_sockets pos
  LEFT JOIN processes p0 ON pos.pid = p0.pid
  LEFT JOIN hash p0_hash ON p0.path = p0_hash.path
  LEFT JOIN processes p1 ON p0.parent = p1.pid
  LEFT JOIN hash p1_hash ON p1.path = p1_hash.path
  LEFT JOIN processes p2 ON p1.parent = p2.pid
  LEFT JOIN hash p2_hash ON p2.path = p2_hash.path
  LEFT JOIN file f ON p0.path = f.path
  LEFT JOIN signature s ON p0.path = s.path
WHERE
  pos.protocol > 0
  AND NOT (
    pos.remote_port IN (53, 443)
    AND pos.protocol IN (6, 17)
  )
  AND pos.remote_address NOT IN (
    '0.0.0.0',
    '::127.0.0.1',
    '127.0.0.1',
    '::ffff:127.0.0.1',
    '::1',
    '::'
  )
  AND pos.remote_address NOT LIKE 'fe80:%'
  AND pos.remote_address NOT LIKE '127.%'
  AND pos.remote_address NOT LIKE '192.168.%'
  AND pos.remote_address NOT LIKE '172.1%'
  AND pos.remote_address NOT LIKE '172.2%'
  AND pos.remote_address NOT LIKE '169.254.%'
  AND pos.remote_address NOT LIKE '172.30.%'
  AND pos.remote_address NOT LIKE '172.31.%'
  AND pos.remote_address NOT LIKE '::ffff:172.%'
  AND pos.remote_address NOT LIKE '10.%'
  AND pos.remote_address NOT LIKE '::ffff:10.%'
  AND pos.remote_address NOT LIKE 'fc00:%'
  AND pos.remote_address NOT LIKE 'fdfd:%'
  AND pos.state != 'LISTEN' -- Ignore most common application paths
  AND p0.path NOT LIKE '/Library/Apple/System/Library/%'
  AND p0.path NOT LIKE '/Library/Application Support/%/Contents/%'
  AND p0.path NOT LIKE '/System/Applications/%'
  AND p0.path NOT LIKE '/System/Library/%'
  AND p0.path NOT LIKE '/System/%'
  AND p0.path NOT LIKE '/usr/libexec/%'
  AND p0.path NOT LIKE '/Users/%/go/bin/%'
  AND p0.path NOT LIKE '/usr/sbin/%' -- Apple programs running from weird places, like the UpdateBrainService
  AND NOT (
    s.identifier LIKE 'com.apple.%'
    AND s.authority = 'Software Signing'
  )
  AND NOT exception_key IN (
    '0,6,7300,safeqclientcore,safeqclientcore,Developer ID Application: Y Soft Corporation, a.s. (3CPED8WGS9),safeqclientcore',
    '0,6,80,fcconfig,fcconfig,Developer ID Application: Fortinet, Inc (AH4XFXJ7DK),fcconfig',
    '0,6,80,prl_naptd,prl_naptd,Developer ID Application: Parallels International GmbH (4C6364ACXT),com.parallels.naptd',
    '0,6,853,at.obdev.littlesnitch.networkextension,at.obdev.littlesnitch.networkextension,Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R),at.obdev.littlesnitch.networkextension',
    '500,17,123,agent,agent,Developer ID Application: Datadog, Inc. (JKFCB4CN7C),agent',
    '500,17,123,Garmin Express,Garmin Express,Developer ID Application: Garmin International (72ES32VZUA),com.garmin.renu.client',
    '500,17,32768,Luna Display,Luna Display,Developer ID Application: Astro HQ LLC (8356ZZ8Y5K),com.astro-hq.LunaDisplayMac',
    '500,17,68,com.docker.backend,com.docker.backend,Developer ID Application: Docker Inc (9BNSXJN65R),com.docker.docker',
    '500,17,8801,zoom.us,zoom.us,Developer ID Application: Zoom Video Communications, Inc. (BJ4HAAB9B3),us.zoom.xos',
    '500,17,9000,Meeting Center,Meeting Center,Developer ID Application: Cisco (DE8Y96K9QP),com.webex.meetingmanager',
    '500,6,21,Cyberduck,Cyberduck,Developer ID Application: David Kocher (G69SCX94XU),ch.sudo.cyberduck',
    '500,6,22,Cyberduck,Cyberduck,Developer ID Application: David Kocher (G69SCX94XU),ch.sudo.cyberduck',
    '500,6,22,devpod-provider-gcloud-darwin-arm64,devpod-provider-gcloud-darwin-arm64,,a.out',
    '500,6,22,goland,goland,Developer ID Application: JetBrains s.r.o. (2ZEFAR8TH3),com.jetbrains.goland',
    '500,6,22,Transmit,Transmit,Developer ID Application: Panic, Inc. (VE8FC488U5),com.panic.Transmit',
    '500,6,2869,Spotify,Spotify,Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client',
    '500,6,32000,Spotify Helper,Spotify Helper,Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client.helper',
    '500,6,32400,PlexMobile,PlexMobile,Apple iPhone OS Application Signing,com.plexapp.plex',
    '500,6,32768,IPNExtension,IPNExtension,Apple Mac OS Application Signing,io.tailscale.ipn.macos.network-extension',
    '500,6,32768,MobileDevicesService,MobileDevicesService,Developer ID Application: GUILHERME RAMBO (8C7439RJLG),codes.rambo.AirBuddy.MobileDevicesService',
    '500,6,3306,dbeaver,dbeaver,Developer ID Application: DBeaver Corporation (42B6MDKMW8),org.jkiss.dbeaver.core.product',
    '500,6,3389,Microsoft Remote Desktop,Microsoft Remote Desktop,Apple Mac OS Application Signing,com.microsoft.rdc.macos',
    '500,6,3389,Microsoft Remote Desktop,Microsoft Remote Desktop,Developer ID Application: Microsoft Corporation (UBF8T346G9),com.microsoft.rdc.macos',
    '500,6,4070,Spotify,Spotify,Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client',
    '500,6,4317,flyctl,flyctl,,a.out',
    '500,6,4318,Code Helper (Plugin),Code Helper (Plugin),Developer ID Application: Microsoft Corporation (UBF8T346G9),com.github.Electron.helper',
    '500,6,5053,bridge,bridge,Developer ID Application: Proton Technologies AG (6UN54H93QT),bridge',
    '500,6,5091,ZoomPhone,ZoomPhone,Developer ID Application: Zoom Video Communications, Inc. (BJ4HAAB9B3),us.zoom.ZoomPhone',
    '500,6,5222,Telegram,Telegram,Apple Mac OS Application Signing,ru.keepcoder.Telegram',
    '500,6,5222,WhatsApp,WhatsApp,Apple Mac OS Application Signing,net.whatsapp.WhatsApp',
    '500,6,5222,WhatsApp,WhatsApp,Developer ID Application: WhatsApp Inc. (57T9237FN3),net.whatsapp.WhatsApp',
    '500,6,5223,KakaoTalk,KakaoTalk,Apple Mac OS Application Signing,com.kakao.KakaoTalkMac',
    '500,6,5228,Clay,Clay,Developer ID Application: Clay Software, Inc. (C68GA48KN3),com.clay.mac',
    '500,6,5228,com.adguard.mac.adguard.network-extension,com.adguard.mac.adguard.network-extension,0u,0g',
    '500,6,5228,com.adguard.mac.adguard.network-extension,com.adguard.mac.adguard.network-extension,Developer ID Application: Adguard Software Limited (TC3Q7MAJXF),com.adguard.mac.adguard.network-extension',
    '500,6,7881,zed,zed,Developer ID Application: Zed Industries, Inc. (MQ55VZLNZQ),dev.zed.Zed',
    '500,6,8009,Spotify Helper,Spotify Helper,Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client.helper',
    '500,6,8080,goland,goland,Developer ID Application: JetBrains s.r.o. (2ZEFAR8TH3),com.jetbrains.goland',
    '500,6,8080,Speedtest,Speedtest,Apple Mac OS Application Signing,com.ookla.speedtest-macos',
    '500,6,80,AdobeAcrobat,AdobeAcrobat,Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.Acrobat.Pro',
    '500,6,80,agent,agent,Developer ID Application: Datadog, Inc. (JKFCB4CN7C),agent',
    '500,6,80,Arc Helper,Arc Helper,Developer ID Application: The Browser Company of New York Inc. (S6N382Y83G),company.thebrowser.browser.helper',
    '500,6,80,Brackets,Brackets,Developer ID Application: CORE.AI SCIENTIFIC TECHNOLOGIES PRIVATE LIMITED (8F632A866K),io.brackets.appshell',
    '500,6,80,Camtasia 2022,Camtasia 2022,Developer ID Application: TechSmith Corporation (7TQL462TU8),com.techsmith.camtasia2022',
    '500,6,80,CEPHtmlEngine Helper,CEPHtmlEngine Helper,Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.cep.CEPHtmlEngine Helper',
    '500,6,80,Chromium Helper,Chromium Helper,,Chromium Helper',
    '500,6,80,Code Helper (Plugin),Code Helper (Plugin),Developer ID Application: Microsoft Corporation (UBF8T346G9),com.github.Electron.helper',
    '500,6,80,Code - Insiders Helper (Plugin),Code - Insiders Helper (Plugin),Developer ID Application: Microsoft Corporation (UBF8T346G9),com.github.Electron.helper',
    '500,6,80,com.docker.backend,com.docker.backend,Developer ID Application: Docker Inc (9BNSXJN65R),com.docker',
    '500,6,80,Creative Cloud UI Helper,Creative Cloud UI Helper,Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.acc.HEXHelper',
    '500,6,80,Discord Helper,Discord Helper,Developer ID Application: Discord, Inc. (53Q6R32WPB),com.hnc.Discord.helper',
    '500,6,80,firefox,firefox,Developer ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.firefox',
    '500,6,80,Google Drive Helper,Google Drive Helper,Developer ID Application: Google LLC (EQHXZ8M8AV),com.google.drivefs.helper',
    '500,6,80,IPNExtension,IPNExtension,Apple Mac OS Application Signing,io.tailscale.ipn.macos.network-extension',
    '500,6,80,Jabra Direct,Jabra Direct,Developer ID Application: GN Audio AS (55LV32M29R),com.jabra.directonline',
    '500,6,80,jcef Helper,jcef Helper,Developer ID Application: JetBrains s.r.o. (2ZEFAR8TH3),org.jcef.jcef.helper',
    '500,6,80,KakaoTalk,KakaoTalk,Apple Mac OS Application Signing,com.kakao.KakaoTalkMac',
    '500,6,80,ksfetch,ksfetch,Developer ID Application: Google LLC (EQHXZ8M8AV),ksfetch',
    '500,6,80,launcher-Helper,launcher-Helper,Developer ID Application: Mojang AB (HR992ZEAE6),com.mojang.mclauncher.helper',
    '500,6,80,Loom Helper,Loom Helper,Developer ID Application: Loom, Inc (QGD2ZPXZZG),com.loom.desktop.helper',
    '500,6,80,Mem Helper,Mem Helper,Developer ID Application: Kevin Moody (9ZLK8RSRVN),org.memlabs.Mem.helper',
    '500,6,80,ngrok,ngrok,Developer ID Application: ngrok LLC (TEX8MHRDQ9),a.out',
    '500,6,80,node,node,Developer ID Application: Node.js Foundation (HX7739G8FX),node',
    '500,6,80,rpi-imager,rpi-imager,Developer ID Application: Floris Bos (WYH7G79LM6),org.raspberrypi.imagingutility',
    '500,6,80,Signal Helper (Renderer),Signal Helper (Renderer),Developer ID Application: Quiet Riddle Ventures LLC (U68MSDN6DR),org.whispersystems.signal-desktop.helper.Renderer',
    '500,6,80,Sky Go,Sky Go,Developer ID Application: Sky UK Limited (GJ24C8864F),com.bskyb.skygoplayer',
    '500,6,80,Slack Helper,Slack Helper,Apple Mac OS Application Signing,com.tinyspeck.slackmacgap.helper',
    '500,6,80,Snagit 2020,Snagit 2020,Apple Mac OS Application Signing,com.TechSmith.Snagit2020',
    '500,6,80,Snagit 2023,Snagit 2023,Developer ID Application: TechSmith Corporation (7TQL462TU8),com.TechSmith.Snagit2023',
    '500,6,80,Snagit 2024,Snagit 2024,Developer ID Application: TechSmith Corporation (7TQL462TU8),com.TechSmith.Snagit2024',
    '500,6,80,SnagitHelper2020,SnagitHelper2020,Apple Mac OS Application Signing,com.techsmith.snagit.capturehelper2020',
    '500,6,80,SnagitHelper2023,SnagitHelper2023,Developer ID Application: TechSmith Corporation (7TQL462TU8),com.techsmith.snagit.capturehelper2023',
    '500,6,80,Spark Desktop Helper,Spark Desktop Helper,Developer ID Application: Readdle Technologies Limited (3L68KQB4HG),com.readdle.SparkDesktop.helper',
    '500,6,80,Spotify,Spotify,Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client',
    '500,6,80,Telegram,Telegram,Apple Mac OS Application Signing,ru.keepcoder.Telegram',
    '500,6,80,thunderbird,thunderbird,Defveloper ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.thunderbird',
    '500,6,80,TIDAL Helper,TIDAL Helper,Developer ID Application: TIDAL Music AS (GK2243L7KB),com.tidal.desktop.helper',
    '500,6,80,Twitter,Twitter,Apple Mac OS Application Signing,maccatalyst.com.atebits.Tweetie2',
    '500,6,80,Wavebox Helper,Wavebox Helper,Developer ID Application: Bookry Ltd (4259LE8SU5),com.bookry.wavebox.helper',
    '500,6,80,WhatsApp,WhatsApp,Developer ID Application: WhatsApp Inc. (57T9237FN3),WhatsApp',
    '500,6,9123,Elgato Control Center,Elgato Control Center,Developer ID Application: Corsair Memory, Inc. (Y93VXCB8Q5),com.corsair.ControlCenter',
    '500,6,993,Mimestream,Mimestream,Developer ID Application: Mimestream, LLC (P2759L65T8),com.mimestream.Mimestream',
    '500,6,993,Spark Desktop Helper,Spark Desktop Helper,Developer ID Application: Readdle Technologies Limited (3L68KQB4HG),com.readdle.SparkDesktop.helper',
    '500,6,993,thunderbird,thunderbird,Developer ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.thunderbird',
    '500,6,995,KakaoTalk,KakaoTalk,Apple Mac OS Application Signing,com.kakao.KakaoTalkMac'
  ) -- Useful for unsigned binaries
  AND NOT alt_exception_key IN (
    '0,6,80,tailscaled,tailscaled,500u,80g',
    '500,6,22,ssh,ssh,0u,500g',
    '500,6,5432,psql,psql,500u,80g',
    '500,6,22,ssh,ssh,500u,0g',
    '500,17,123,limactl,limactl,500u,80g',
    '500,17,123,gvproxy,gvproxy,500u,80g',
    '500,6,80,qemu-system-x86_64,qemu-system-x86_64,500u,80g',
    '500,6,22,ssh,ssh,500u,20g',
    '500,6,22,ssh,ssh,500u,80g',
    '500,6,80,git-remote-http,git-remote-http,500u,20g',
    '500,6,3307,cloud_sql_proxy,cloud_sql_proxy,0u,0g',
    '500,6,3307,cloud-sql-proxy,cloud-sql-proxy,500u,20g',
    '500,6,3307,cloud_sql_proxy,cloud_sql_proxy,500u,20g',
    '500,6,80,chainlink,chainlink,500u,20g',
    '500,6,80,copilot-agent-macos-arm64,copilot-agent-macos-arm64,500u,20g',
    '500,6,80,firefox,firefox,500u,20g',
    '500,6,80,qemu-system-aarch64,qemu-system-aarch64,500u,80g'
  )
  AND NOT alt_exception_key LIKE '500,6,22,packer-plugin-amazon%,packer-plugin-amazon_%,500u,20g'
  AND NOT (
    alt_exception_key LIKE '500,6,%,syncthing,syncthing,0u,500g'
    AND remote_port > 79
  )
  AND NOT (
    alt_exception_key LIKE '500,6,%,nuclei,nuclei,500u,80g'
    AND remote_port > 20
    AND remote_port < 32000
  )
  AND NOT (
    exception_key LIKE '500,6,%,syncthing,syncthing,Developer ID Application: Kastelo AB (LQE5SYM783),syncthing'
    AND remote_port > 24
  )
  AND NOT (
    exception_key LIKE '500,6,%,syncthing,syncthing,Developer ID Application: Jakob Borg (LQE5SYM783),syncthing'
    AND remote_port > 24
  )
  AND NOT (
    alt_exception_key = '500,6,80,main,main,500u,20g'
    AND p0.path LIKE '/var/folders/%/T/go-build%/b001/exe/main'
  ) -- Wider
  AND NOT (
    (
      pos.remote_port IN (80, 123, 587, 999)
      OR pos.remote_port > 1024
    )
    AND id_exception_key IN (
      'Apple Mac OS Application Signing,com.microsoft.OneDrive-mac',
      'Apple Mac OS Application Signing,com.ookla.speedtest-macos',
      'Apple Mac OS Application Signing,net.whatsapp.WhatsApp.ServiceExtension',
      'Developer ID Application: Adguard Software Limited (TC3Q7MAJXF),com.adguard.mac.adguard.network-extension',
      'Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.AdobeResourceSynchronizer',
      'Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.lightroomCC',
      'Developer ID Application: Adobe Inc. (JQ525L2MZD),com.adobe.Reader',
      'Developer ID Application: Bitdefender SRL (GUNFMW623Y),com.bitdefender.cst.net.dci.dci-network-extension',
      'Developer ID Application: Bookry Ltd (4259LE8SU5),com.bookry.wavebox.helper',
      'Developer ID Application: Brave Software, Inc. (KL8N8XSYF4),com.brave.Browser.helper',
      'Developer ID Application: Brave Software, Inc. (KL8N8XSYF4),com.brave.Browser.nightly.helper',
      'Developer ID Application: Cisco (DE8Y96K9QP),Cisco-Systems.SparkHelper',
      'Developer ID Application: Cloudflare Inc. (68WVV388M8),CloudflareWARP',
      'Developer ID Application: Docker Inc (9BNSXJN65R),com.docker',
      'Developer ID Application: Docker Inc (9BNSXJN65R),com.docker.docker',
      'Developer ID Application: Epic Games International, S.a.r.l. (96DBZ92D3Y),com.epicgames.EpicGamesLauncher',
      'Developer ID Application: Epic Games International, S.a.r.l. (96DBZ92D3Y),com.epicgames.UE4EditorServices',
      'Developer ID Application: Fortinet, Inc (AH4XFXJ7DK),fctupdate',
      'Developer ID Application: GEORGE NACHMAN (H7V7XYVQ7D),com.googlecode.iterm2',
      'Developer ID Application: Google LLC (EQHXZ8M8AV),com.google.Chrome.helper',
      'Developer ID Application: Google LLC (EQHXZ8M8AV),com.google.GoogleUpdater',
      'Developer ID Application: Google LLC (EQHXZ8M8AV),com.google.one.NetworkExtension',
      'Developer ID Application: GUILHERME RAMBO (8C7439RJLG),codes.rambo.AirBuddy.MobileDevicesService',
      'Developer ID Application: Loom, Inc (QGD2ZPXZZG),com.loom.desktop',
      'Developer ID Application: Microsoft Corporation (UBF8T346G9),com.microsoft.edgemac.helper',
      'Developer ID Application: Microsoft Corporation (UBF8T346G9),com.microsoft.teams2.helper',
      'Developer ID Application: Microsoft Corporation (UBF8T346G9),com.microsoft.VSCode.helper',
      'Developer ID Application: Microsoft Corporation (UBF8T346G9),net.java.openjdk.java',
      'Developer ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.firefox',
      'Developer ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.firefoxdeveloperedition',
      'Developer ID Application: Mozilla Corporation (43AQ936H96),org.mozilla.thunderbird',
      'Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R),at.obdev.littlesnitch.networkextension',
      'Developer ID Application: Opera Software AS (A2P9LX4JPN),com.operasoftware.Opera.helper',
      'Developer ID Application: Oracle America, Inc. (VB5E2TV963),net.java.openjdk.java',
      'Developer ID Application: Parallels International GmbH (4C6364ACXT),com.parallels.naptd',
      'Developer ID Application: Private Internet Access, Inc. (5357M5NW9W),com.privateinternetaccess.vpn',
      'Developer ID Application: Red Hat, Inc. (HYSCB8KRL2),gvproxy',
      'Developer ID Application: Shanghai Lunkuo Technology Co., Ltd (T3UBR9Y3B2),com.bambulab.bambu-studio',
      'Developer ID Application: Skype Communications S.a.r.l (AL798K98FX),com.skype.skype.Helper',
      'Developer ID Application: Slack Technologies, Inc. (BQR82RBBHL),com.tinyspeck.slackmacgap.helper',
      'Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client',
      'Developer ID Application: Spotify (2FNC3A47ZF),com.spotify.client.helper',
      'Developer ID Application: Tailscale Inc. (W5364U7YZB),io.tailscale.ipn.macsys.network-extension',
      'Developer ID Application: TechSmith Corporation (7TQL462TU8),com.techsmith.camtasia2024',
      'Developer ID Application: TechSmith Corporation (7TQL462TU8),com.techsmith.snagit.capturehelper2020',
      'Developer ID Application: TechSmith Corporation (7TQL462TU8),com.techsmith.snagit.capturehelper2024',
      'Developer ID Application: The Browser Company of New York Inc. (S6N382Y83G),company.thebrowser.Browser',
      'Developer ID Application: The Browser Company of New York Inc. (S6N382Y83G),company.thebrowser.browser.helper',
      'Developer ID Application: Valve Corporation (MXGJJ98X76),com.valvesoftware.steam',
      'Developer ID Application: Valve Corporation (MXGJJ98X76),com.valvesoftware.steam.helper',
      'Developer ID Application: Vivaldi Technologies AS (4XF3XNRN6Y),com.vivaldi.Vivaldi.helper',
      'Developer ID Application: Vladimir Prelovac (TFVG979488),com.apple.WebKit.Networking',
      'Developer ID Application: WhatsApp Inc. (57T9237FN3),net.whatsapp.WhatsApp',
      'Developer ID Application: WhatsApp Inc. (57T9237FN3),net.whatsapp.WhatsApp.ServiceExtension',
      'Developer ID Application: Wizards of the Coast LLC (63JKFDP62M),com.wizards.mtga',
      'Developer ID Application: Zed Industries, Inc. (MQ55VZLNZQ),dev.zed.Zed-Preview',
      'Developer ID Application: Zoom Video Communications, Inc. (BJ4HAAB9B3),us.zoom.xos',
      'Developer ID Application: Zwift, Inc (C2GM8Y9VFM),ZwiftAppSilicon'
    )
  )
GROUP BY
  p0.cmdline
