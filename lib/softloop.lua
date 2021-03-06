local Softloop={}

local Formatters=require 'formatters'

function Softloop:new(o)
  o=o or {} -- create object if user does not provide one
  setmetatable(o,self)
  self.__index=self
  o.voices=o.voices or {softcut.VOICE_COUNT-1,softcut.VOICE_COUNT}
  if #o.voices>2 then
    o.voices={o.voices[1],o.voices[2]}
  end

  o.dir=nil
  o.loaded=false
  o.playing=false
  o.clockid=nil

  if not util.file_exists(_path.audio.."softloop") then
    os.execute("mkdir -p ".._path.audio.."softloop/")
    os.execute("cp ".._path.code.."softloop/samples/* ".._path.audio.."softloop/")
  end

  -- TODO: add params
  params:add_group("SOFTLOOP",10)
  local voice_options={}
  for i=1,softcut.VOICE_COUNT/2 do
    table.insert(voice_options,(i*2-1).."+"..(i*2))
  end
  params:add_option("softloop_voice","softcut voice",voice_options,1)
  params:add{
    type='binary',
    name="load random",
    id='softloop_loadrand',
    behavior='trigger',
    action=function(v)
      if o.dir~=nil and self.files~=nil and #self.files>0 then
        params:set("softloop_file",self.files[math.random(#self.files)])
      end
    end
  }
  params:add_file("softloop_file","load specific",_path.audio)
  params:set_action("softloop_file",function(x)
    if x~=_path.audio and x~=nil then
      o:load_file(x)
    end
  end)
  params:add_control("softloop_level","level",controlspec.new(0,2,'lin',0.01,0.5,'amp',0.01/2))
  params:set_action("softloop_level",function(x)
    for _,i in ipairs(o.voices) do
      softcut.level(i,x)
    end
  end)
  params:add {
    type='control',
    id='softloop_fc',
    name='filter cutoff',
    controlspec=controlspec.new(20,20000,'exp',50,20000,'Hz',50/20000),
    formatter=Formatters.format_freq,
    action=function(value)
      for _,i in ipairs(o.voices) do
        softcut.post_filter_fc(i,value)
      end
    end
  }
  params:add {
    type='control',
    id='softloop_rc',
    name='filter rq',
    controlspec=controlspec.new(0.05,1,'lin',0.01,1,'',0.01/1),
    action=function(value)
      for _,i in ipairs(o.voices) do
        softcut.post_filter_rq(i,value)
      end
    end
  }
  params:add_control("softloop_reverse","reverse",controlspec.new(0,100,'lin',1,2,'%',1/100))
  params:add_control("softloop_jump","jump",controlspec.new(0,100,'lin',1,15,'%',1/100))
  params:add_control("softloop_hold","hold",controlspec.new(0,100,'lin',1,5,'%',1/100))
  params:add_control("softloop_offset","l/r offset",controlspec.new(0,0.2,'lin',0.01,0,'s',0.01/2))
  params:set_action("softloop_offset",function(x)
    softcut.voice_sync(o.voices[1],o.voices[2],x)
  end)
  params:set_action("softloop_voice",function(x)
    print("initializing voices ",x*2-1,x*2)
    o.voices={x*2-1,x*2}
    for buf,i in ipairs(o.voices) do
      softcut.enable(i,1)
      softcut.buffer(i,buf)
      softcut.level(i,params:get("softloop_level"))
      softcut.loop(i,1)
      softcut.loop_start(i,260)
      softcut.loop_end(i,261)
      softcut.position(i,260)
      softcut.rate(i,1.0)
      softcut.play(i,1)
      softcut.pan(i,buf*2-3)

      softcut.fade_time(i,0.05)

      softcut.post_filter_dry(i,0.0)
      softcut.post_filter_lp(i,1.0)
      softcut.post_filter_rq(i,params:get("softloop_rc"))
      softcut.post_filter_fc(i,params:get("softloop_fc"))

      softcut.pre_filter_dry(i,1.0)
      softcut.pre_filter_lp(i,1.0)
      softcut.pre_filter_rq(i,1.0)
      softcut.pre_filter_fc(i,20100)
    end
  end)

  params:set("softloop_voice",#voice_options)
  self:load_dir("/home/we/dust/audio/softloop/loop_hh_groove__beats16_bpm90.wav")
  return o
end

function Softloop:load_dir(x)
  self.dir,_,_=string.match(x,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  self.files=util.scandir(self.dir)
  for i,f in ipairs(self.files) do
    self.files[i]=self.dir..f
  end
end

function Softloop:mangle()
  if self.mangleid~=nil then
    clock.cancel(self.mangleid)
  end
  self.mangleid=clock.run(function()
    clock.sync(1)
    self:set_pos(self.start)
    while true do
      if math.random()<params:get("softloop_hold")/100 then
        self:jump_and_hold()
      elseif math.random()<params:get("softloop_jump")/100 then
        self:jump()
      elseif math.random()<params:get("softloop_reverse")/100 then
        self:reverse()
      end
      clock.sync(1)
      -- self:emit()
    end
  end)
end

function Softloop:emit()
  if self.samplerate==nil then
    do return end
  end
  if (tempo~=clock.get_tempo()) or (math.random()<0.05) or (self.reversed and math.random()<0.3) or self.loaded_file then
    print("softloop: syncing")
    self.loaded_file=nil
    self.reversed=nil
    tempo=clock.get_tempo()
    for _,i in ipairs(self.voices) do
      softcut.rate(i,1.0*self.samplerate/48000*clock.get_tempo()/self.bpm)
      softcut.loop_start(i,self.start)
      softcut.loop_end(i,self.start+self.duration)
    end
    local pos=self.start
    if next(self.breaks)~=nil then
      pos=pos+self.breaks[math.random(#self.breaks)]
    end
    self:set_pos(pos)
  end
  -- if math.random()<params:get("softloop_reverse")/100 then
  --   print("softloop: reverse")
  --   self:reverse()
  --   self.reversed=true
  -- end
  -- if math.random()<params:get("softloop_jump")/100 then
  --   print("softloop: jump")
  --   self:jump()
  -- end
  -- if math.random()<params:get("softloop_hold")/100 then
  --   print("softloop: hold")
  --   self:jump_and_hold()
  -- end
end

function Softloop:set_pos(pos)
  print("softloop: setting to pos "..pos)
  for _,i in ipairs(self.voices) do
    softcut.rate(i,1.0*self.samplerate/48000*clock.get_tempo()/self.bpm)
  end
  softcut.position(self.voices[1],pos)
  softcut.position(self.voices[2],pos)
  softcut.voice_sync(self.voices[1],self.voices[2],params:get("softloop_offset"))
  softcut.pan(self.voices[1],1)
  softcut.pan(self.voices[2],-1)
end

function Softloop:jump()
  if next(self.breaks_on_beat)==nil then
    do return end
  end
  print("softloop: jump")
  local pos=self.start
  pos=pos+self.breaks_on_beat[math.random(#self.breaks_on_beat)]
  for _,i in ipairs(self.voices) do
    softcut.loop_start(i,self.start)
    softcut.loop_end(i,self.start+self.duration)
  end
  self:set_pos(pos)
end

function Softloop:jump_and_hold()
  if next(self.breaks)==nil then
    do return end
  end
  print("softloop: jump and hold")
  local pos=self.start
  local break_num=math.random(#self.breaks-1)
  local break2_num=math.random(break_num+1,#self.breaks)
  print(break_num,break2_num)
  for _,i in ipairs(self.voices) do
    softcut.loop_start(i,pos+self.breaks[break_num])
    softcut.loop_end(i,pos+self.breaks[break2_num])
  end
  self:set_pos(pos+self.breaks[break_num])
end

function Softloop:reverse()
  for _,i in ipairs(self.voices) do
    softcut.rate(i,1.0*self.samplerate/48000*clock.get_tempo()/self.bpm*-1)
  end
end

function Softloop:glitch()
  local start=self.start+(math.random(1,1000)/1000*self.duration)
  local start_end=start+clock.get_beat_sec()/(math.random(1,16))
  if self.clockid~=nil then
    clock.cancel(self.clockid)
  end
  self.clockid=clock.run(function()
    for _,i in ipairs(self.voices) do
      softcut.loop_start(i,start)
      softcut.loop_end(i,start_end)
      -- softcut.position(i,start)
    end
    self:set_pos(start)
    clock.sleep(clock.get_beat_sec()*math.random(1,3)/4)
    for _,i in ipairs(self.voices) do
      softcut.rate_slew_time(i,0)
    end
  end)
end

function Softloop:slow()
  if self.clockid~=nil then
    clock.cancel(self.clockid)
  end
  self.clockid=clock.run(function()
    for _,i in ipairs(self.voices) do
      softcut.rate_slew_time(i,clock.get_beat_sec()*64)
      softcut.rate(i,1.0*self.samplerate/48000*clock.get_tempo()/self.bpm*0.1)
    end
    clock.sync(math.random(1,3))
    for _,i in ipairs(self.voices) do
      softcut.rate_slew_time(i,0)
    end
  end)
end

function Softloop:load_file(fname)
  if fname==nil then
    fname=self.files[math.random(#self.files)]
  end
  print("softloop: loading "..fname)

  self.fname=fname
  self.beats=4
  self.bpm=clock.get_tempo()
  local beats=fname:match("beats%d+")
  if beats~=nil then
    beats=beats:match("%d+")
    if beats~=nil then
      self.beats=tonumber(beats)
    end
  end
  local bpm=fname:match("bpm%d+")
  if bpm~=nil then
    bpm=bpm:match("%d+")
    if bpm~=nil then
      self.bpm=tonumber(bpm)
    end
  end

  self.breaks={}
  norns.system_cmd("/home/we/dust/code/softloop/lib/aubioonset -i "..fname.." -O hfc -f -M "..(60/self.bpm/8).." -s -60 -t 0.6 -B 128 -H 128 -T samples",function(x)
    local bs={}
    local bs_beat={}
    for s in x:gmatch("%S+") do
      local sample_break=tonumber(s)
      local is_close=true
      for i=0,self.beats do
        local sample_beat=i/self.beats*self.samples
        if math.abs(sample_break-sample_beat)<1000 then
          is_close=true
        end
      end
      print("softloop: break at "..(sample_break/48000))
      table.insert(bs,sample_break/48000)
      if is_close then
        table.insert(bs_beat,sample_break/48000)
      end
    end
    self.breaks=bs
    self.breaks_on_beat=bs_beat
  end)

  self.ch,self.samples,self.samplerate=audio.file_info(self.fname)
  self.duration=self.samples/48000.0
  self.start=280-self.duration
  if self.ch==1 then
    softcut.buffer_read_mono(self.fname,0,self.start,self.duration,1,1)
    softcut.buffer_read_mono(self.fname,0,self.start,self.duration,1,2)
  else
    softcut.buffer_read_stereo(self.fname,0,self.start,self.duration)
  end

  self.playing=true
  self.loaded_file=true

  local tempo=clock.get_tempo()
  for _,i in ipairs(self.voices) do
    softcut.rate(i,1.0*self.samplerate/48000*clock.get_tempo()/self.bpm)
    softcut.loop_start(i,self.start)
    softcut.loop_end(i,self.start+self.duration)
  end
  self:set_pos(self.start)

  self:mangle()

end

return Softloop

