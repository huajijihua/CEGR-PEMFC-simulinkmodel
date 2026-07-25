classdef RouteACegrValveConstitutiveTest < matlab.unittest.TestCase
    %RouteACegrValveConstitutiveTest Tests CEGR valve closed/open laws.

    methods (Test, TestTags = {'Unit', 'Simscape'})
        function testOfficialClosedAndOpenConstituents(testCase)
            result = run_routeA_cegr_valve_closed_open_unit_test();

            testCase.verifyTrue(result.closedForwardPassed, ...
                'Closed state must block forward mass, energy, and species flow.');
            testCase.verifyTrue(result.closedReversePassed, ...
                'Closed state must block reverse mass, energy, and species flow.');
            testCase.verifyTrue(result.openForwardPassed, ...
                'Open Local Restriction must pass positive forward flow.');
        end
    end
end
