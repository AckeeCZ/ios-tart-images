packer {
    required_plugins {
        tart = {
            version = ">= 1.16.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

source "tart-cli" "tart" {
    from_ipsw    = "https://updates.cdn-apple.com/2026FallFCS/afcfc88e-bbe6-44bf-a5da-07c56eebc06c/UniversalMac_27.0_26A428_Restore.ipsw"
    vm_name      = "macos-base"
    cpu_count    = 4
    memory_gb    = 8
    disk_size_gb = 100
    disk_format  = "asif"
    ssh_password = "admin"
    ssh_username = "admin"
    ssh_timeout  = "180s"
    headless     = true
    recovery_partition = "keep"
    // Replaces the Setup Assistant flow, requires Tart 2.33.0+ and macOS 27+ on both the host and guest VM
    run_extra_args = [
        "--provisioning-opts=${join(",", [
            "fullName=Managed via Tart",
            "username=admin",
            "password=admin",
            "logsInAutomatically=true",
            "enablesRemoteLogin=true",
        ])}",
    ]
    boot_command = [
        # Wait for first-boot provisioning to finish automatic login
        "<wait120s>",
        # Enable Keyboard navigation
        # This is so that we can navigate the System Settings app using the keyboard
        "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<wait10s><enter>",
        "<wait10s><wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
        # Disable Gatekeeper (1/2)
        "<wait10s>sudo spctl --global-disable<enter>",
        "<wait10s>admin<enter>",
        # Disable Gatekeeper (2/2)
        # Opening System Settings through Spotlight is not very reliable, sometimes opens System information
        "<wait10s>open '/System/Applications/System Settings.app'<enter>",
        # Wait for System Settings to fully open before navigating with the keyboard
        "<wait120s>",
        "<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Privacy & Security<enter>",
        "<wait10s><leftShiftOn><tab><tab><tab><tab><tab><tab><leftShiftOff>",
        "<wait10s><down><wait1s><down><wait1s><enter>",
        "<wait10s>admin<enter>",
        "<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",
        # Quit System Settings
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Refocus Terminal after quitting System Settings
        "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<wait10s><enter>",
        # Sharing is no longer listed in the View menu on macOS 27
        "<wait10s>open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension'<enter>",
        # Enable Screen Sharing through the UI to grant the required TCC permissions
        "<wait10s><tab><tab><tab><tab><tab><tab><spacebar>",
        # Type in the password to allow enabling Screen Sharing
        "<wait10s>admin<enter>",
        # Quit System Settings
        "<wait10s><leftAltOn>q<leftAltOff>",
        # Quit Terminal
        "<wait10s><leftAltOn>q<leftAltOff>",
    ]

    // A (hopefully) temporary workaround for Virtualization.Framework's
    // installation process not fully finishing in a timely manner
    create_grace_time = "30s"
}

build {
    sources = ["source.tart-cli.tart"]

    provisioner "shell" {
        inline = [
            // Enable passwordless sudo
            "echo admin | sudo -S sh -c \"mkdir -p /etc/sudoers.d/; echo 'admin ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/admin-nopasswd\"",
            // Set timezone to Prague
            "sudo systemsetup -settimezone 'Europe/Prague' 2>/dev/null",
            // Disable screensaver at login screen
            "sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0",
            // Disable screensaver for admin user
            "defaults -currentHost write com.apple.screensaver idleTime 0",
            // Prevent the VM from sleeping
            "sudo systemsetup -setsleep Off 2>/dev/null",
            // Disable screen lock
            //
            // Note that this only works if the user is logged-in,
            // i.e. not on login screen.
            "sysadminctl -screenLock off -password admin",
        ]
    }

    provisioner "shell" {
        inline = [
            # Ensure that Gatekeeper is disabled
            "spctl --status | tee /dev/stderr | grep -q 'assessments disabled'",
            # Ensure that Screen Sharing was enabled
            "sudo launchctl print system/com.apple.screensharing > /dev/null || { echo 'Screen Sharing is not enabled'; exit 1; }",
            # Ensure that FileVault remains disabled by default
            "sudo fdesetup status | tee /dev/stderr | grep -q 'FileVault is Off'",
        ]
    }

    provisioner "shell" {
        inline = [
            "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
            "echo \"security unlock-keychain -p admin\" >> ~/.zprofile",
            "echo \"export LANG=en_US.UTF-8\" >> ~/.zprofile",
            "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile",
            "echo \"export HOMEBREW_NO_AUTO_UPDATE=1\" >> ~/.zprofile",
            "echo \"export HOMEBREW_NO_INSTALL_CLEANUP=1\" >> ~/.zprofile",
            "source ~/.zprofile",
            "brew --version",
            "brew update",
            "brew install wget cmake gcc git-lfs jq",
            "git lfs install",
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install libyaml rbenv", # https://github.com/rbenv/ruby-build/discussions/2118
            "echo 'if which rbenv > /dev/null; then eval \"$(rbenv init -)\"; fi' >> ~/.zprofile",
            "source ~/.zprofile",
            "rbenv install 3.4.9",
            "rbenv global 3.4.9",
            "gem install bundler",
        ]
    }
}