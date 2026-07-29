function report = routeA_check_dependencies(paths, strict)
% Check the minimum MATLAB and Route A dependencies before startup.
%
% The checker reports logical library resolution instead of requiring the
% development machine's absolute FuelCell_lib path.

if nargin < 1 || isempty(paths)
    paths = routeA_project_paths();
end
if nargin < 2 || isempty(strict)
    strict = true;
end

report = struct();
report.schemaVersion = "RouteA_Dependency_Report_v01";
report.strict = logical(strict);
report.passed = true;
report.errors = strings(0, 1);
report.warnings = strings(0, 1);
report.checks = repmat(checkTemplate(), 0, 1);
report.paths = paths;
report.matlabRelease = string(version('-release'));
report.fuelCellLibrary = "";

for idx = 1:numel(paths.requiredFiles)
    filePath = paths.requiredFiles{idx};
    report = addCheck(report, "file:" + string(filePath), isfile(filePath), ...
        "error", "Required Route A file is missing: " + string(filePath));
end

report = addCheck(report, 'matlab_release', ...
    ~isMATLABReleaseOlderThan('R2025b'), 'error', ...
    "MATLAB R2025b or newer is required by the validated Route A baseline.");

report = addProductCheck(report, 'Simulink', 'Simulink');
report = addProductCheck(report, 'Simscape', 'Simscape');

libraryPath = which(paths.fuelCellLibraryName);
if isempty(libraryPath)
    libraryPath = which([paths.fuelCellLibraryName '.slx']);
end
if ~isempty(libraryPath)
    report.fuelCellLibrary = string(libraryPath);
end
report = addCheck(report, 'FuelCell_lib', ~isempty(libraryPath), ...
    dependencySeverity(strict), ...
    "FuelCell_lib could not be resolved by its logical MATLAB library name.");

for idx = 1:numel(paths.requiredFunctions)
    functionName = paths.requiredFunctions{idx};
    if contains(functionName, '.')
        functionExists = exist(functionName, 'class') == 8 || ...
            ~isempty(which(functionName));
    else
        functionExists = exist(functionName, 'file') > 0 || ...
            ~isempty(which(functionName));
    end
    report = addCheck(report, "function:" + string(functionName), ...
        functionExists, 'error', ...
        "Required MATLAB function or class is unavailable: " + string(functionName));
end

if ~isfile(paths.satkReuseLibrariesFile)
    report = addCheck(report, 'satk_reuse_libraries', false, 'warning', ...
        "The development-only .satk reuse library declaration is unavailable; runtime library resolution remains authoritative.");
end

end

function report = addProductCheck(report, productName, licenseName)
try
    productAvailable = ~isempty(ver(productName));
catch
    productAvailable = false;
end
try
    licenseAvailable = license('test', licenseName);
catch
    licenseAvailable = false;
end
passed = productAvailable && licenseAvailable;
detail = "Required product or license is unavailable: " + string(productName);
report = addCheck(report, "product:" + string(productName), passed, ...
    'error', detail);
end

function severity = dependencySeverity(strict)
if strict
    severity = 'error';
else
    severity = 'warning';
end
end

function report = addCheck(report, name, passed, severity, detail)
check = checkTemplate();
check.name = string(name);
check.passed = logical(passed);
check.severity = string(severity);
check.detail = string(detail);
report.checks(end + 1) = check;
if ~passed
    if string(severity) == "error"
        report.passed = false;
        report.errors(end + 1, 1) = string(detail);
    else
        report.warnings(end + 1, 1) = string(detail);
    end
end
end

function check = checkTemplate()
check = struct( ...
    'name', "", ...
    'passed', false, ...
    'severity', "", ...
    'detail', "");
end
