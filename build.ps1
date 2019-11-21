try {
    $VS_PATH = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"

    if ( -not (Test-Path "$VS_PATH")) {
        echo "Error: VS_PATH isn't set correctly! Update the variable in build.ps1 for your system or implement it with vswhere!"
        exit 1
    }

    if ( -not (Test-Path "Thirdparty\ACT\Advanced Combat Tracker.exe" )) {
        echo 'Error: Please run tools\fetch_deps.py'
        exit 1
    }


    if ( -not (Test-Path "Thirdparty\FFXIV_ACT_Plugin\SDK\FFXIV_ACT_Plugin.Common.dll" )) {
        echo 'Error: Please run tools\fetch_deps.py'
        exit 1
    }

    # This assumes Visual Studio 2019 is installed in C:. You might have to change this depending on your system.
    $ENV:PATH = "$VS_PATH\MSBuild\Current\Bin;${ENV:PATH}";


    if ( -not (Test-Path .\Thirdparty\curl\builds\libcurl.dll)) {
        echo "==> Building cURL..."
        cd Thirdparty\curl\winbuild

        echo "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" amd64"           | Out-File -Encoding ascii tmp_build.bat
        echo "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x64" | Out-File -Encoding ascii -Append tmp_build.bat
        echo "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" x86"             | Out-File -Encoding ascii -Append tmp_build.bat
        echo "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x86" | Out-File -Encoding ascii -Append tmp_build.bat

        cmd "/c" "tmp_build.bat"
        sleep 3
        del tmp_build.bat

        cd ..\builds
        copy .\libcurl-vc16-x64-release-dll-ipv6-sspi-winssl\bin\libcurl.dll libcurl-x64.dll
        copy .\libcurl-vc16-x86-release-dll-ipv6-sspi-winssl\bin\libcurl.dll libcurl.dll

        cd ..\..\..
    }

    echo "==> Building..."

    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln"
    if (-not $?) { exit 1 }

    echo "==> Building archive..."

    cd out\Release

    rm -Recurse resources
    mv libs\resources .

    $text = [System.IO.File]::ReadAllText("$PWD\..\..\OverlayPlugin\Properties\AssemblyInfo.cs");
    $regex = [regex]::New('\[assembly: AssemblyVersion\("([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+"\)');
    $m = $regex.Match($text);

    if (-not $m) {
        echo "Error: Version number not found in the AssemblyInfo.cs!"
        exit 1
    }

    $version = $m.Groups[1]
    $archive = "..\OverlayPlugin-$version.7z"

    if (Test-Path $archive) { rm $archive }
    7z a $archive "-x!*.xml" "-x!*.pdb" OverlayPlugin.dll OverlayPlugin.dll.config resources fr-FR zh-CN README.md `
        LICENSE.txt libs\fr-FR libs\ja-JP libs\ko-KR libs\zh-CN libs\*.dll libs\*\libcurl.dll

    $archive = "..\OverlayPlugin-$version.zip"

    if (Test-Path $archive) { rm $archive }
    7z a $archive "-x!*.xml" "-x!*.pdb" OverlayPlugin.dll OverlayPlugin.dll.config resources fr-FR zh-CN README.md `
        LICENSE.txt libs\fr-FR libs\ja-JP libs\ko-KR libs\zh-CN libs\*.dll libs\*\libcurl.dll
} catch {
    Write-Error $Error[0]
}
