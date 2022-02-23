# infinite-breaks


```git
diff --git a/crone/softcut b/crone/softcut
--- a/crone/src/SoftcutClient.h
+++ b/crone/src/SoftcutClient.h
@@ -22,7 +22,7 @@ namespace crone {
         static constexpr float MinRate = static_cast<float>(softcut::Resampler::OUT_BUF_FRAMES * -1);
         enum { MaxBlockFrames = 2048};
         enum { BufFrames = 16777216 };
-        enum { NumVoices = 6 };
+        enum { NumVoices = 12 };
        enum { NumBuffers = 2 };
         typedef enum { SourceAdc=0 } SourceId;
         typedef Bus<2, MaxBlockFrames> StereoBus;
diff --git a/lua/core/softcut.lua b/lua/core/softcut.lua
index 27fd1616..ca66b48b 100644
--- a/lua/core/softcut.lua
+++ b/lua/core/softcut.lua
@@ -18,7 +18,7 @@ local controlspec = require 'core/controlspec'
 -- @section constants

 -- @field number of voices
-SC.VOICE_COUNT = 6
+SC.VOICE_COUNT = 12
 -- @field length of buffer in seconds
 SC.BUFFER_SIZE = 16777216 / 48000
```
