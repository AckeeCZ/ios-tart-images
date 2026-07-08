packer {
    required_plugins {
        tart = {
            version = ">= 1.20.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

variable "xcode_version" {
  type = string
}

source "tart-cli" "tart" {
    vm_base_name = "registry.hub.docker.com/ackee/tart-macos-base:tahoe"
    vm_name      = "ackee-xcode:${var.xcode_version}"
    cpu_count    = 4
    memory_gb    = 8
    disk_size_gb = 100
    ssh_password = "admin"
    ssh_username = "admin"
    ssh_timeout  = "120s"
    headless     = true
}

build {
    sources = ["source.tart-cli.tart"]

    provisioner "file" {
        source      = pathexpand("~/Downloads/Xcode_${var.xcode_version}.xip")
        destination = "/Users/admin/Downloads/Xcode_${var.xcode_version}.xip"
    }

    # xcode
    provisioner "shell" {
        inline = [
            "echo 'export PATH=/usr/local/bin/:$PATH' >> ~/.zprofile",
            "source ~/.zprofile",
            "brew install xcodes",
            "echo 'Starting Xcode installation'",
            "sudo xcodes install ${var.xcode_version} --experimental-unxip --path /Users/admin/Downloads/Xcode_${var.xcode_version}.xip --select --empty-trash",
            "echo 'Xcode installed'",
            "xcodebuild -downloadPlatform ios",
            "xcodebuild -runFirstLaunch",
            "/usr/sbin/softwareupdate --install-rosetta --agree-to-license",
            # enable all plugins
            "defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES",
            # enable all macros
            "defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES",
            # enable prebuilt SPM packages
            "defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES",
            # drop bottles kept by HOMEBREW_NO_INSTALL_CLEANUP=1, keep the api JSON cache
            "brew cleanup -s --prune=all || true",
            "find \"$(brew --cache)\" -mindepth 1 -maxdepth 1 ! -name api -exec rm -rf {} + || true",
            "rm -rf ~/Library/Caches/com.apple.dt.Xcode || true"
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install carthage ca-certificates",
            "brew cleanup -s --prune=all || true",
            "find \"$(brew --cache)\" -mindepth 1 -maxdepth 1 ! -name api -exec rm -rf {} + || true",
        ]
    }

    # inspired by https://github.com/actions/runner-images/blob/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/configure-machine.sh#L33-L61
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "sudo security delete-certificate -Z FF6797793A3CD798DC5B2ABEF56F73EDC9F83A64 /Library/Keychains/System.keychain",
            "sudo mkdir -p /usr/local/bin/",
            "curl -o add-certificate.swift https://raw.githubusercontent.com/actions/runner-images/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/add-certificate.swift",
            "swiftc add-certificate.swift",
            "sudo mv ./add-certificate /usr/local/bin/add-certificate",
            "curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
            "curl -o DeveloperIDG2CA.cer https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer",
            "sudo add-certificate AppleWWDRCAG3.cer",
            "sudo add-certificate DeveloperIDG2CA.cer",
            "rm add-certificate* *.cer"
        ]
    }

    # mise & tuist
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "curl https://mise.run | sh",
            "~/.local/bin/mise activate --shims >> ~/.zprofile",
            "source ~/.zprofile",
            "mise version",
            "mise install tuist swiftlint --yes",
            "xcrun simctl delete all",
            "xcrun simctl create 'iPhone 13 Pro Max' 'iPhone 13 Pro Max'",
            "xcrun simctl create 'iPhone 17 Pro' 'iPhone 17 Pro'",
            # prebuild the simulator dyld shared cache (~2-4 GB) so fresh clones don't
            # burn minutes of CPU in update_dyld_sim_shared_cache on first simulator boot
            "xcrun simctl runtime dyld_shared_cache update --all || sleep 180",
            # keep ~/.local/share/mise/installs (tuist/swiftlint live there), drop caches only
            "mise cache clear || true",
            "rm -rf ~/.local/share/mise/downloads ~/Library/Caches/mise || true",
        ]
    }

    # KMP
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install openjdk@17",
            "echo 'export PATH=\"/opt/homebrew/opt/openjdk@17/bin:$PATH\"' >> ~/.zprofile",
            "echo 'export CPPFLAGS=\"-I/opt/homebrew/opt/openjdk@17/include:$CPPFLAGS\"' >> ~/.zprofile",
            "echo 'export JAVA_HOME=\"/opt/homebrew/opt/openjdk@17\"' >> ~/.zprofile",
            "brew cleanup -s --prune=all || true",
            "find \"$(brew --cache)\" -mindepth 1 -maxdepth 1 ! -name api -exec rm -rf {} + || true",
        ]
    }

    # React Native - Expo
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "echo Install yarn node fastlane cocoapods",
            "brew install yarn node@20 fastlane cocoapods",
            "echo Link node",
            "brew link --overwrite node@20",
            "echo Enable corepack",
            "corepack enable",
            "echo Corepack use yarn",
            "corepack use yarn@4",
            "echo Run npm i",
            "npm i -g eas-cli",
            # do NOT touch ~/.cache — ~/.cache/node/corepack is the live install of the
            # pinned yarn@4 (and ~/package.json holds the pin), not a disposable cache
            "npm cache clean --force || true",
            "brew cleanup -s --prune=all || true",
            "find \"$(brew --cache)\" -mindepth 1 -maxdepth 1 ! -name api -exec rm -rf {} + || true",
        ]
    }

    # reclaim disk space before shutdown: purge logs and transient files, then
    # zero-fill free space so `tart push` compresses it away and `tart pull`
    # restores it as holes (sparse file) on CI hosts. The free space check below
    # doubles as a guard that the zerofill file was actually deleted.
    provisioner "shell" {
        timeout = "30m"
        inline = [
            "sudo log erase --all || true",
            "sudo rm -rf /Library/Logs/* ~/Library/Logs/* /private/var/log/*.log /private/tmp/* 2>/dev/null || true",
            "rm -rf ~/.Trash/* ~/Downloads/* 2>/dev/null || true",
            # local APFS snapshots would pin freed blocks in the pushed image
            "tmutil listlocalsnapshots / || true",
            "sudo tmutil deletelocalsnapshots / 2>/dev/null || true",
            # leave a 1 GiB margin so the volume never hits 100%
            "FREE_MB=$(df -m /System/Volumes/Data | awk 'NR==2 {print $4}')",
            "COUNT=$((FREE_MB - 1024))",
            "echo Zero-filling $COUNT MB of free space",
            "[ $COUNT -gt 0 ] && dd if=/dev/zero of=$HOME/zerofill bs=1m count=$COUNT || true",
            "sync",
            "rm -f $HOME/zerofill",
            "sync",
            "df -h",
        ]
    }

    // check there is at least 15GB of free space and fail if not
    provisioner "shell" {
        inline = [
        "source ~/.zprofile",
        "echo Checking disk space",
        "df -h",
        "export FREE_MB=$(df -m | awk '{print $4}' | head -n 2 | tail -n 1)",
        "echo Available space in MB = $FREE_MB",
        "[[ $FREE_MB -gt 15000 ]] && echo OK || exit 1",
        ]
    }
}