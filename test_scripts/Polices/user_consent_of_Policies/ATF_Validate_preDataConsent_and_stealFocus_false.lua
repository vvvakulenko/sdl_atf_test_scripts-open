---------------------------------------------------------------------------------------------
-- Requirement summary:
--      [Policies] DISALLOWED: "pre_DataConsent" policies and "steal_focus" validation
--
-- Description:
--    Validation of "steal_focus" section in case "steal_focus:false" and <app id> policies are assigned to the application
--     1. Used preconditions:
--        SDL and HMI are started
--        Overwrite preloaded PT(with "steal_focus"=false in "pre_DataConsent")
--
--     2. Performed steps
--        Send RPC with soft button with STEAL_FOCUS SystemAction
--
-- Expected result:
--     PoliciesManager must validate "steal_focus" section, SDL must reject RPC->
--     respond (resultCode:DISALLOWED, success:false) to mobile application
---------------------------------------------------------------------------------------------
--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local Preconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonSteps:DeleteLogsFileAndPolicyTable()
Preconditions:BackupFile("sdl_preloaded_pt.json")
testCasesForPolicyTable:Precondition_updatePolicy_By_overwriting_preloaded_pt("files/Base4InPreDataConsent_preloaded_pt.json")

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:Send_Alert_check_disallowed_steal_focus()
  local RequestIDAlert = self.mobileSession:SendRPC("Alert",
  {
    alertText1 = "alertText1",
    ttsChunks =
    {
      {
        text = "TTSChunk",
        type = "TEXT",
      },
    },
    duration = 3000,
    softButtons =
    {
      {
        type = "IMAGE",
        image =

        {
          value = "icon.png",
          imageType = "STATIC",
        },
        softButtonID = 1171,
        systemAction = "STEAL_FOCUS",
      },
    },
  })
  EXPECT_RESPONSE(RequestIDAlert, { success = false, resultCode = "DISALLOWED" })
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_SDLStop()
  StopSDL()
end
testCasesForPolicyTable:Restore_preloaded_pt()