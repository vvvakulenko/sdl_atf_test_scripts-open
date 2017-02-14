---------------------------------------------------------------------------------------------
-- Requirement summary:
-- SDL must send WARNINGS (success:true) to mobile app in case HMI respond WARNINGS to at least one HMI-portions
-- [TTS Interface] HMI does NOT respond to IsReady and mobile app sends RPC that must be splitted
--
-- Description:
-- test is intended to check that SDL sends WARNINGS (success:true) to mobile app in case HMI respond WARNINGS to at least one HMI-portions
-- in this particular test it is checked case when TTS.Speak gets UNSUPPORTED_RESOURCE and UI.PerformAudioPassThru gets WARNINGS from HMI
--
-- 1. Used preconditions:
-- HMI does not respond to UI.IsReady
-- App is registered and activated SUCCESSFULLY
-- 2. Performed steps:
-- MOB -> SDL: sends PerformAudioPassThru
-- HMI -> SDL: UI.PerformAudioPassThru (WARNINGS), TTS.Speak (UNSUPPORTED_RESOURCE),
--
-- Expected result:
-- SDL -> HMI: resends TTS.Speak and UI.PerformAudioPassThru
-- SDL -> MOB: PerformAudioPassThru (result code: UNSUPPORTED_RESOURCE, success: true)
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
-- ToDo (vvvakulenko): remove after issue "ATF does not stop HB timers by closing session and connection" is resolved
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForTTS_IsReady = require('user_modules/IsReady_Template/testCasesForTTS_IsReady')
local testCasesForPerformAudioPassThru = require('user_modules/shared_testcases/testCasesForPerformAudioPassThru')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
local mobile_session = require('mobile_session')

--[[ Local Variables ]]
local ServerAddress = commonFunctions:read_parameter_from_smart_device_link_ini("ServerAddress")

--[[ General Precondition before ATF start ]]
commonFunctions:SDLForceStop()
commonSteps:DeleteLogsFiles()
commonSteps:DeletePolicyTable()
testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED"},"PerformAudioPassThru")

--[[ General Settings for configuration ]]
Test = require('user_modules/connecttest_initHMI')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_InitHMI_OnReady()
  testCasesForTTS_IsReady.InitHMI_onReady_without_TTS_IsReady(self, 1)
  EXPECT_HMICALL("TTS.IsReady")
  -- Do not send HMI response of TTS.IsReady
end

function Test:Precondition_connectMobile()
  self:connectMobile()
end

function Test:Precondition_StartSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

commonSteps:RegisterAppInterface("Precondition_RegisterAppInterface")

function Test:Precondition_ActivationApp()
  local request_id = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications[config.application1.registerAppInterfaceParams.appName]})
  EXPECT_HMIRESPONSE(request_id)
  :Do(function(_,data)
    if (data.result.isSDLAllowed ~= true) then
      local request_id1 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
      EXPECT_HMIRESPONSE(request_id1)
      :Do(function(_,_)
        self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = ServerAddress}})
        EXPECT_HMICALL("BasicCommunication.ActivateApp")
        :Do(function(_,data1)
          self.hmiConnection:SendResponse(data1.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
        end)
      end)
    end
  end)
  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"}) 
end

commonSteps:PutFile("Precondition_PutFile", "icon.png")

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_PerformAudioPassThru_TTS_Speak_UNSUPPORTED_RESOURCE()
  local cor_id= self.mobileSession:SendRPC("PerformAudioPassThru",
    {
      initialPrompt = {{ text = "Makeyourchoise", type = "TEXT" }},
      audioPassThruDisplayText1 = "DisplayText1",
      audioPassThruDisplayText2 = "DisplayText2",
      samplingRate = "8KHZ",
      maxDuration = 2000,
      bitsPerSample = "8_BIT",
      audioType = "PCM",
      muteAudio = true,
      audioPassThruIcon = { imageType = "STATIC", value = "icon.png" }
    })

    EXPECT_HMICALL("TTS.Speak",
    {
      speakType = "AUDIO_PASS_THRU",
      ttsChunks = {{ text = "Makeyourchoise", type = "TEXT" }},
      appID = self.applications[config.application1.registerAppInterfaceParams.appName]
    })
    :Do(function(_,data2)
      self.hmiConnection:SendNotification("TTS.Started",{ })
      local function ttsSpeakResponce()
        self.hmiConnection:SendResponse (data2.id, "TTS.Speak", "UNSUPPORTED_RESOURCE", {info = "unsupported resource"})
        self.hmiConnection:SendNotification("TTS.Stopped")
      end
      RUN_AFTER(ttsSpeakResponce,1500)
    end)

    EXPECT_HMICALL("UI.PerformAudioPassThru",
    {
      appID = self.applications[config.application1.registerAppInterfaceParams.appName],
      audioPassThruDisplayTexts =
        {{fieldName = "audioPassThruDisplayText1", fieldText = "DisplayText1"},
        {fieldName = "audioPassThruDisplayText2", fieldText = "DisplayText2"}},
      maxDuration = 2000,
      muteAudio = true,
      audioPassThruIcon = { imageType = "STATIC", value = "icon.png" }
    })
    :Do(function(_,data3)
      local function UIPerformAoudioResponce()
        self.hmiConnection:SendResponse(data3.id, "UI.PerformAudioPassThru", "WARNINGS", {})
      end
      RUN_AFTER(UIPerformAoudioResponce,1500)
    end)

     if
    (self.appHMITypes["NAVIGATION"] == true) or
    (self.appHMITypes["COMMUNICATION"] == true) or
    (self.isMediaApplication == true) then

    EXPECT_NOTIFICATION("OnHMIStatus",
      {hmiLevel = "FULL", audioStreamingState = "ATTENUATED", systemContext = "MAIN"},
      {hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN"})
    :Times(2)
    else
      EXPECT_NOTIFICATION("OnHMIStatus"):Times(0)
    end

    EXPECT_RESPONSE(cor_id, { success = true, resultCode = "UNSUPPORTED_RESOURCE", info = "unsupported resource"})
    EXPECT_NOTIFICATION("OnHashChange"):Times(0)
    commonTestCases:DelayedExp(1500)
  end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Restore_preloaded_file()
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_SDLStop()
  StopSDL()
end

return Test