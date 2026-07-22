@{
    Domain = @{
        Fqdn    = 'hufflab.internal'
        NetBios = 'HUFFLAB'
    }

    Network = @{
        Subnet         = '10.0.100.0/24'
        PrefixLength   = 24
        Gateway        = '10.0.100.1'
        HostIp         = '10.0.100.1'
        SwitchName     = 'LabSwitch'
        NatName        = 'LabNAT'
        Statics        = @{
            DC01  = '10.0.100.10'
            WDS01 = '10.0.100.20'
            CM01  = '10.0.100.30'
        }
        DhcpScopeStart = '10.0.100.100'
        DhcpScopeEnd   = '10.0.100.199'
        DnsForwarders  = @('1.1.1.1', '9.9.9.9')
    }

    Paths = @{
        LabRoot         = 'G:\HyperV\ad-pxe-lab'
        IsoDir          = 'G:\HyperV\ad-pxe-lab\ISO'
        VhdDir          = 'G:\HyperV\ad-pxe-lab\VHD'
        ParentVhdx      = 'G:\HyperV\ad-pxe-lab\VHD\WS2025-parent.vhdx'
        UnattendTemplate = 'unattend\unattend-server-base.xml'
        IsoFiles        = @{
            WS2025  = 'Windows_Server_2025_Evaluation.iso'
            Win11   = 'Windows_11_Enterprise_Evaluation.iso'
            WS2022  = 'Windows_Server_2022_Evaluation.iso'
            SQL2022 = 'SQL_Server_2022_Evaluation.iso'
            ConfigMgr = 'ConfigMgr_2509_Evaluation.exe'
            ADK     = 'adksetup.exe'
            WinPE   = 'adkwinpesetup.exe'
        }
    }

    ParentDisk = @{
        SizeGB         = 60
        EfiPartitionMB = 260
        MsrPartitionMB = 16
        ImageName      = 'Windows Server 2025 Standard Evaluation (Desktop Experience)'
    }

    HostRequirements = @{
        MinimumMemoryGB   = 32
        MinimumFreeDiskGB = 500
        SecureBootTemplate = 'MicrosoftWindows'
    }

    VMs = @{
        DC01 = @{
            Name = 'DC01'; CPU = 2; MemoryGB = 4; MemoryType = 'Static'; DiskGB = 60
            DiskType = 'Differencing'; BootDevice = 'VHD'; SwitchName = 'LabSwitch'
        }
        WDS01 = @{
            Name = 'WDS01'; CPU = 2; MemoryGB = 2; MemoryType = 'Static'; DiskGB = 60
            DiskType = 'Differencing'; BootDevice = 'VHD'; SwitchName = 'LabSwitch'
        }
        CM01 = @{
            Name = 'CM01'; CPU = 4; MemoryGB = 16; MemoryType = 'Static'; DiskGB = 150
            DiskType = 'Fixed'; BootDevice = 'VHD'; SwitchName = 'LabSwitch'
        }
        CL01 = @{
            Name = 'CL01'; CPU = 2; MemoryGB = 4; MemoryMinimumGB = 1; MemoryMaximumGB = 4; MemoryType = 'Dynamic'; DiskGB = 60
            DiskType = 'Dynamic'; BootDevice = 'Network'; SwitchName = 'LabSwitch'
        }
        CL02 = @{
            Name = 'CL02'; CPU = 2; MemoryGB = 4; MemoryMinimumGB = 1; MemoryMaximumGB = 4; MemoryType = 'Dynamic'; DiskGB = 60
            DiskType = 'Dynamic'; BootDevice = 'Network'; SwitchName = 'LabSwitch'
        }
        REF01 = @{
            Name = 'REF01'; CPU = 2; MemoryGB = 4; MemoryMinimumGB = 1; MemoryMaximumGB = 4; MemoryType = 'Dynamic'; DiskGB = 60
            DiskType = 'Dynamic'; BootDevice = 'DVD'; SwitchName = 'LabSwitch'
        }
    }

    TimeZone = 'Eastern Standard Time'
}
