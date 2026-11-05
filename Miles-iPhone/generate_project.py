"""Generate a dependency-free Xcode project; no account or signing secret included."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
objects = []
def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def quote(value):
    return json.dumps(str(value))
def obj(name, body):
    objects.append(f'{ident(name)} = {{ {body} }};')
def refs(names):
    return '(' + ','.join(ident(n) for n in names) + ',)'

files = ['Core.swift', 'Recorder.swift', 'MilesApp.swift']
for name in files:
    obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(name)}; sourceTree = "<group>";')
    obj('build-' + name, f'isa = PBXBuildFile; fileRef = {ident(name)};')
obj('Info.plist', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Miles.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["build-" + f for f in files])}; runOnlyForDeploymentPostprocessing = 0;')
for phase in ['resources', 'frameworks']:
    obj(phase, f'isa = PBX{phase.title()}BuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('group', f'isa = PBXGroup; children = {refs(["app-group", "products"])}; sourceTree = "<group>";')
obj('app-group', f'isa = PBXGroup; children = {refs(files + ["Info.plist"])}; path = Miles; sourceTree = "<group>";')
obj('products', f'isa = PBXGroup; children = {refs(["product"])}; name = Products; sourceTree = "<group>";')
for mode in ['Debug', 'Release']:
    obj('project-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }};')
    settings = {
        'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '',
        'PRODUCT_BUNDLE_IDENTIFIER': 'local.miles.gps.trial', 'PRODUCT_NAME': 'Miles',
        'INFOPLIST_FILE': 'Miles/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO',
        'TARGETED_DEVICE_FAMILY': '1', 'SWIFT_VERSION': '5.0',
        'SWIFT_STRICT_CONCURRENCY': 'minimal', 'IPHONEOS_DEPLOYMENT_TARGET': '16.0',
        'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO',
        'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
        'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    }
    obj('target-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ ' + ' '.join(f'{k} = {quote(v)};' for k,v in settings.items()) + ' };')
for prefix in ['project', 'target']:
    obj(prefix + '-configs', f'isa = XCConfigurationList; buildConfigurations = {refs([prefix + "-Debug", prefix + "-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("target-configs")}; buildPhases = {refs(["sources", "frameworks", "resources"])}; buildRules = (); dependencies = (); name = Miles; productName = Miles; productReference = {ident("product")}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; TargetAttributes = {{ {ident("target")} = {{ CreatedOnToolsVersion = 16.0; SystemCapabilities = {{ com.apple.BackgroundModes = {{ enabled = 1; }}; }}; }}; }}; }}; buildConfigurationList = {ident("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = es; hasScannedForEncodings = 0; knownRegions = (es,en,Base,); mainGroup = {ident("group")}; productRefGroup = {ident("products")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["target"])};')
project = root / 'Miles.xcodeproj'
project.mkdir(exist_ok=True)
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {ident("project")}; }}\n', encoding='utf-8')
schemes = project / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target")}" BuildableName="Miles.app" BlueprintName="Miles" ReferencedContainer="container:Miles.xcodeproj"/>'
(schemes / 'Miles.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding='utf-8')
print(project)
