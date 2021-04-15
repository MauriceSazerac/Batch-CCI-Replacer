# Source - the reference to replace things with
# Target - the item to be replaced/make a new version of

param (
    [string]
    [Alias("c", "config")]
    $configJson = "./test.json",

    [Parameter(Mandatory=$false)]
    [switch]
    [Alias("s")]
    $SetupTargets = $false,

    [Parameter(Mandatory=$false)]
    [switch]
    [Alias("t")]
    $SetupTargetsOnly = $false
 )


function Swap-Outfits($batch, $outfits, $sources, $char, $slot)
{
    #Write-Host "    Would have swapped:"
    #$outfits | ForEach-Object {Write-Host "      $($_)"}
    #Write-Host "    with:"
    #$sources | ForEach-Object {Write-Host "      $($_)"}    

    $pathOut = "$($batch.Workspace)\$($batch.ModName)\TekkenGame\Content\Character\Item\Customize\$($char)\$($slot)";  
    if ($batch.Debug) { Write-Host ("Create dir: $($pathOut)"); }
    New-Item -Path $pathOut -type Directory *> $null;
    Set-Location $pathOut;

    foreach ($outfit in $outfits)
    {
        if ($batch.Debug) { Write-Host "    Working on outfit: $($outfit)" }

        if ( ($sources | Measure-Object).Count -gt 1 )
        {
            # identify source and perform selected swaps
        } 
        else 
        {
            & $batch.UassetRenamer ($outfit.PSPath | Resolve-Path | Convert-Path) ($sources.PSPath | Resolve-Path | Convert-Path)
        }
    }
}


# Save current location to restore later
$oldWorkingDirectory = Get-Location;

$allCharCodes = @("AKI", "ANN", "ARB", "ASA", "ASK", "BOB", "BRY", "CRZ", "DNC", "DRA", "DVJ", "EDD", "ELZ", "FEN", "FRV", "GAN", "HEI", "HWO", "ITA", "JAC", "JIN", "JUL", "KAZ", "KIN", "KNM", "KUM", "KZM", "LAR", "LAW", "LEE", "LEI", "LEO", "LIL", "LTN", "MAR", "MIG", "MRX", "MRY", "MRZ", "MUT", "NIN", "NSA", "NSB", "NSC", "NSD", "PAN", "PAU", "STE", "XIA", "YOS", "ZAF");

try 
{
    # Load the config for this batch
    $batch = Get-Content $configJson | ConvertFrom-Json;
    if ($batch.Debug) { $batch | ConvertTo-Json; }

    # Sanity checking
    if ($batch.Debug) { Write-Host "Checking Workspace exists"; }
    if ( -Not(Test-Path "$($batch.Workspace)") )
    {
        throw "ERROR: could not find Workspace folder.";
    }
    if ( -Not(Test-Path "$($batch.Workspace)\$($batch.Source)\TekkenGame\Content\Character\Item\Customize") )
    {
        throw "ERROR: Source folder not found or not setup correctly.";
    }

    # Target File Setup - If Target folder does not exist, or flags are set get the CCI files from the AllAssets folder
    if ( -Not(Test-Path "$($batch.Workspace)\$($batch.Target)") -Or $SetupTargets -Or $SetupTargetsOnly)
    {
        Write-Host "Getting target CCIs from All Assets to be replaced.";
        
        if ( -Not(Test-Path "$($batch.AllAssets)") ) 
        {
            throw "ERROR: could not find All Assets folder.";
        }
        
        foreach ($char in $allCharCodes)
        {
            if ($batch.Debug) { Write-Host "Working on character: $($char)"; }  

            foreach ($slot in $batch.OutfitSlots)
            {
                if ($batch.Debug) { Write-Host "  Working on slot: $($slot)"; }

                $pathMain = "$($batch.AllAssets)\TekkenGame\Content\Character\Item\Customize\$($char)\$($slot)"
                $pathDlc = "$($batch.AllAssets)\Character\Item\Customize\$($char)\$($slot)"
                $pathTarget = "$($batch.Workspace)\$($batch.Target)\TekkenGame\Content\Character\Item\Customize\$($char)\$($slot)"

                foreach ($pathSource in @($pathMain, $pathDlc))
                {
                    if ( Test-Path($pathSource) )
                    {
                        if ( -Not(Test-Path -Path $pathTarget) )
                        {
                            New-Item -ItemType directory -Path $pathTarget *> $null;
                        }

                        Copy-Item -Path "$($pathSource)\*" -Destination $pathTarget -Recurse -Force;
                        
                        if ($batch.Debug) { Write-Host "       copied: $($pathSource) to $($pathTarget)"; }
                    }
                }
            }
        }

        # If SetupTargetsOnly flag is set nothing further to do
        if ($SetupTargetsOnly)
        {            
            if ($batch.Debug) { Write-Host "Nothing further to do."; }
            exit;
        }
    }

    # Setup Mod Dir
    if (Test-Path "$($batch.Workspace)\$($batch.ModName)") 
    {
        Remove-Item "$($batch.Workspace)\$($batch.ModName)" -Recurse
    };

    $outputFolder = "$($batch.Workspace)\$($batch.ModName)\TekkenGame\Content\Character\Item\Customize";
    if ($batch.Debug) { Write-Host ("Create dir: $($outputFolder)"); }
    New-Item -Path $outputFolder -type Directory *> $null;

    # Outfit Swapping 
    foreach ($char in $batch.CharCodes) 
    {     
        $uChar = $char.ToString().ToUpper();
        $lChar = $char.ToString().ToLower();

        if ($batch.Debug) { Write-Host "Working on character: $($uChar)"; }    
    
        foreach ($slot in $batch.OutfitSlots)
        {
            if ($batch.Debug) { Write-Host "  Working on slot: $($slot)"; }

            switch -Regex ( $char ) 
            {
                default 
                {
                    $pathTarget = "$($batch.Workspace)\$($batch.Target)\TekkenGame\Content\Character\Item\Customize\$($char)\$($slot)";
                    if (Test-Path $pathTarget) 
                    {
                        $outfits = Get-ChildItem $pathTarget
                    }
                    else 
                    {
                        Write-Host "    No targets found."
                        continue;
                    }
                    
                    $pathSource = "$($batch.Workspace)\$($batch.Source)\TekkenGame\Content\Character\Item\Customize\$($char)\$($slot)";                    
                    if (Test-Path $pathSource) 
                    {
                        $sources = Get-ChildItem $pathSource
                    }
                    else 
                    {
                        Write-Host "    No source to replace target with."
                        continue;
                    }

                    Swap-Outfits $batch $outfits $sources $char $slot
                }
            }
        }
    }

    # rename all the files without the -new.uasset part
    Set-Location $outputFolder;
    Get-ChildItem "*-new.uasset" -Recurse | Rename-Item -NewName {$_.Name -replace '-new.uasset','.uasset'}
}
catch 
{
    Write-Host $PSItem.ToString();    
}
finally
{
    # Put the user back where they started
    Set-Location $oldWorkingDirectory;
}

 
