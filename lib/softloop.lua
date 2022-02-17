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

  -- TODO: add params
  params:add_group("SOFTLOOP",10)
  params:add_file("softloop_file","file",_path.audio)
  params:set_action("softloop_file",function(x)
    if x~=_path.audio and x~=nil then
      o:load_file(x)
    end
  end)

  params:add_file("softloop_folder","folder (for rand)",_path.audio)
  params:set_action("softloop_folder",function(x)
    if x~=_path.audio and x~=nil then
      o.dir,_,_=string.match(x,"(.-)([^\\/]-%.?([^%.\\/]*))$")
      o.files=util.scandir(o.dir)
      for i,f in ipairs(o.files) do
        o.files[i]=o.dir..f
      end
    end
  end)
  params:add{
    type='binary',
    name="load random",
    id='softloop_loadrand',
    behavior='trigger',
    action=function(v)
      if o.dir~=nil then
        print(o.dir)
        o:load_file()
      end
    end
  }
  local voice_options={}
  for i=1,softcut.VOICE_COUNT/2 do
    table.insert(voice_options,(i*2-1).."+"..(i*2))
  end
  params:add_control("softloop_level","level",controlspec.new(0,2,'lin',0.01,0.2,'amp',0.01/2))
  params:set_action("softloop_level",function(x)
    for _,i in ipairs(o.voices) do
      softcut.level(i,x)
    end
  end)
  params:add {
    type='control',
    id='softloop_fc',
    name='filter cutoff',
    controlspec=controlspec.new(20,20000,'exp',0,20000,'Hz'),
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
  params:add_option("softloop_voice","sc voice",voice_options,softcut.VOICE_COUNT/2)
  params:set_action("softloop_voice",function(x)
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
    end
  end)
  params:add_control("softloop_reverse","reverse",controlspec.new(0,100,'lin',1,1,'%',1/100))
  params:add_control("softloop_jump","jump",controlspec.new(0,100,'lin',1,1,'%',1/100))
  params:add_control("softloop_hold","hold",controlspec.new(0,100,'lin',1,1,'%',1/100))
  return o
end

function Softloop:mangle()
  local tempo=clock.get_tempo()
  if self.mangleid~=nil then
    clock.cancel(self.mangleid)
  end
  self.mangleid=clock.run(function()
    while true do
      if not self.playing then
        clock.sleep(1)
      else
        clock.sync(1/16)
        if math.abs(math.floor(clock.get_beats())-clock.get_beats())<0.01 then
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
            local pos=self.start+self.duration/self.beats*math.random(0,self.beats-1)
            for v,i in ipairs(self.voices) do
              softcut.position(i,pos)
              softcut.pan(i,v*2-3)
            end
          end
          if math.random()<params:get("softloop_reverse")/100 then
            print("softloop: reverse")
            self:reverse()
            self.reversed=true
          end
          if math.random()<params:get("softloop_jump")/100 then
            print("softloop: jump")
            self:jump()
          end
          if math.random()<params:get("softloop_hold")/100 then
            print("softloop: hold")
            self:jump_and_hold()
          end
        end
      end
    end
  end)
end

function Softloop:jump()
  local pos=self.start+self.duration/self.beats*math.random(0,self.beats-1)
  for _,i in ipairs(self.voices) do
    softcut.position(i,pos)
  end
end

function Softloop:jump_and_hold()
  local pos=self.start+self.duration/self.beats*math.random(0,self.beats-1)
  local pos_end=pos+self.duration/self.beats*math.random(1,2)
  if pos_end>self.start+self.duration then
    pos_end=self.start+self.duration
  end
  for _,i in ipairs(self.voices) do
    softcut.loop_start(i,pos)
    softcut.loop_end(i,pos_end)
    softcut.position(i,pos)
  end
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
      softcut.position(i,start)
    end
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
  print("loading "..fname)

  for buf,i in ipairs(self.voices) do
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

    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_rq(i,params:get("softloop_rc"))
    softcut.post_filter_fc(i,params:get("softloop_fc"))

    softcut.pre_filter_dry(i,1.0)
    softcut.pre_filter_lp(i,1.0)
    softcut.pre_filter_rq(i,1.0)
    softcut.pre_filter_fc(i,20100)
  end

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
  self:mangle()
end

return Softloop

