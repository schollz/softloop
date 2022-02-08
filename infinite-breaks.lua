-- infinite breaks
--

ib={
  files={},
}

function ib.init()
  ib.files = util.scandir(_path.audio.."infinite-breaks/")
  for i, f in ipairs(ib.files) do
    ib.files[i]=_path.audio.."infinite-breaks/"..f
  end
  for i=5,6 do
    softcut.enable(i,1)
    softcut.buffer(i,i-4)
    softcut.level(i,1.0)
    softcut.loop(i,1)
    softcut.loop_start(i,260)
    softcut.loop_end(i,261)
    softcut.position(i,260)
    softcut.rate(i,1.0)
    softcut.play(i,1)
  end

  local tempo=clock.get_tempo()
  clock.run(function()
    while true do 
      clock.sleep(1)
      if tempo~=clock.get_tempo() then 
        temp=clock.get_tempo()
        ib.sync()
      end
    end
  end)
end

function ib.random_file()
  for i=1,1000 do 
    local fname = ib.files[math.random(#ib.files)]
    local beats=fname:match("beats%d+")
    if beats~=nil then 
      beats=beats:match("%d+")
      if beats~=nil then 
        beats=tonumber(beats)
      end
    end
    local bpm=fname:match("_bpm%d+")
    if bpm~=nil then 
      bpm=bpm:match("%d+")
      if bpm~=nil then 
        bpm=tonumber(bpm)
      end
    end
    if beats~=nil and bpm~=nil then 
      do return fname,bpm,beats end
    end
  end
end

function ib.load_file()
  ib.fname,ib.bpm,ib.beats=ib.random_file()
  ib.ch,ib.samples,ib.samplerate=audio.file_info(ib.fname)
  ib.duration=ib.samples/48000.0
  for k,v in pairs(ib) do 
    print(k,v)
  end
  ib.start=280-ib.duration
  if ib.ch==1 then 
    softcut.buffer_read_mono(ib.fname, 0, ib.start, ib.duration, 1, 1)
    softcut.buffer_read_mono(ib.fname, 0, ib.start, ib.duration, 1, 2)
  else
    softcut.buffer_read_stereo(ib.fname, 0, ib.start, ib.duration)
  end
  ib.sync()
end

function ib.sync()
  clock.run(function()
    clock.sync(1)
    for i=5,6 do 
      softcut.loop_start(i,ib.start)
      softcut.loop_end(i,ib.start+ib.duration)
      softcut.position(i,ib.start)
      softcut.rate(i,1.0*ib.samplerate/48000*clock.get_tempo()/ib.bpm)
    end
  end)
end


function init()
  ib.init()
  ib.load_file()

end

