---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] Master Reset
--
-- Description:
-- SDL receives MASTER_RESET
-- 1. Used preconditions
-- Activate app
-- Perform master_reset
-- Start SDL
--
-- 2. Performed steps
-- Check LPT is equal to preloaded_PT
--
-- Expected result:
-- Policy Manager must revert Local Policy Table to the Preload Policy Table
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTableSnapshot = require ('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')

--[[ Preconditions ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
function Test:TestStep_CheckLocalPT()
  local hmi_app1_id = self.applications[config.application1.registerAppInterfaceParams.appName]

  local ServerAddress = "127.0.0.1"--commonSteps:get_data_from_SDL_ini("ServerAddress")

  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications[config.application1.registerAppInterfaceParams.appName]})

  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,_)

    local RequestId1 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
    EXPECT_HMIRESPONSE( RequestId1, {result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
    :Do(function(_,_)
      self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
        {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = ServerAddress, isSDLAllowed = true}})
    end)

    if ( commonSteps:file_exists( '/tmp/fs/mp/images/ivsu_cache/sdl_snapshot.json') == false) then
      self:FailTestCase(" \27[31m /tmp/fs/mp/images/ivsu_cache/sdl_snapshot.json is created \27[0m")
    else
      testCasesForPolicyTableSnapshot:verify_PTS(true, {config.application1.registerAppInterfaceParams.appID}, {config.deviceMAC},{hmi_app1_id}, "print")
    end
  end)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test
