local InfiniteBreaks = {}

function InfiniteBreaks:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    o.voices = o.voices or {7,8}
    if #o.voices > 2 then
        o.voices = {o.voices[1], o.voices[2]}
    end

    o.dir = nil
    o.loaded = false
    o.playing = false
    o.clockid = nil



    -- TODO: add params
    params:add_group("INFINITE BREAKS", 3)
    params:add_file("infinitebreaks_file", "file", _path.audio)
    params:set_action("infinitebreaks_file", function(x)
        if x ~= _path.audio and x ~= nil then
            o:load_file(x)
        end
    end)
    -- TODO: delete these lines
    o.dir=_path.audio.."jungle-sounds-spliced/"
    o.files = util.scandir(o.dir)
    for i, f in ipairs(o.files) do
        o.files[i] = o.dir .. f
    end
    params:add_file("infinitebreaks_folder", "folder (for rand)", _path.audio.."jungle-sounds-spliced")
    params:set_action("infinitebreaks_folder", function(x)
        if x ~= _path.audio and x ~= nil then
            o.dir, _, _ = string.match(x, "(.-)([^\\/]-%.?([^%.\\/]*))$")
            o.files = util.scandir(o.dir)
            for i, f in ipairs(o.files) do
                o.files[i] = o.dir .. f
            end
        end
    end)
    params:add{
        type = 'binary',
        name = "load random",
        id = 'infinitebreaks_loadrand',
        behavior = 'trigger',
        action = function(v)
            if o.dir ~= nil then
                print(o.dir)
                o:load_file()
            end
        end
    }
    o:mangle()
    o:load_file()       
    return o
end

function InfiniteBreaks:mangle()
    local tempo = clock.get_tempo()
    if self.mangleid ~= nil then
        clock.cancle(self.mangleid)
    end
    self.mangleid = clock.run(function()
        while true do
            if not self.playing then
                clock.sleep(1)
            else
                clock.sync(1 / 16)
                if math.abs(math.floor(clock.get_beats()) - clock.get_beats()) < 0.02 then
                    if (tempo ~= clock.get_tempo()) or (math.random() < 0.05) or self.loaded_file then
                        print("syncing")
                        self.loaded_file=nil
                        tempo = clock.get_tempo()
                        for _, i in ipairs(self.voices) do
                            softcut.rate(i, 1.0 * self.samplerate / 48000 * clock.get_tempo() / self.bpm)
                            softcut.loop_start(i, self.start)
                            softcut.loop_end(i, self.start + self.duration)
                        end
                        local pos = self.start + self.duration / self.beats * math.random(0, self.beats - 1)
                        for _, i in ipairs(self.voices) do
                            softcut.position(i, pos)
                        end
                    end
                    if math.random() < 0.01 then
                        print("reverse")
                        self:reverse()
                    end 
                    if math.random() < 0.01 then
                        print("jump")
                        self:jump()
                    end 
                    if math.random() < 0.01 then
                        print("jump and hold")
                        self:jump_and_hold()
                    end
                end
            end
        end
    end)
end

function InfiniteBreaks:jump()
    local pos = self.start + self.duration / self.beats * math.random(0, self.beats - 1)
    for _, i in ipairs(self.voices) do
        softcut.position(i, pos)
    end
end

function InfiniteBreaks:jump_and_hold()
    local pos = self.start + self.duration / self.beats * math.random(0, self.beats - 1)
    local pos_end = pos + self.duration / self.beats * math.random(1, 4)
    if pos_end > self.start + self.duration then
        pos_end = self.start + self.duration
    end
    for _, i in ipairs(self.voices) do
        softcut.loop_start(i, pos)
        softcut.loop_end(i, pos_end)
        softcut.position(i, pos)
    end
end

function InfiniteBreaks:reverse()
    for _, i in ipairs(self.voices) do
        softcut.rate(i, 1.0 * self.samplerate / 48000 * clock.get_tempo() / self.bpm * -1)
    end
end

function InfiniteBreaks:glitch()
    local start = self.start + (math.random(1, 1000) / 1000 * self.duration)
    local start_end = start + clock.get_beat_sec() / (math.random(1, 16))
    if self.clockid ~= nil then
        clock.cancel(self.clockid)
    end
    self.clockid = clock.run(function()
        for _, i in ipairs(self.voices) do
            softcut.loop_start(i, start)
            softcut.loop_end(i, start_end)
            softcut.position(i, start)
        end
        clock.sleep(clock.get_beat_sec() * math.random(1, 3) / 4)
        for _, i in ipairs(self.voices) do
            softcut.rate_slew_time(i, 0)
        end
    end)
end

function InfiniteBreaks:slow()
    if self.clockid ~= nil then
        clock.cancel(self.clockid)
    end
    self.clockid = clock.run(function()
        for _, i in ipairs(self.voices) do
            softcut.rate_slew_time(i, clock.get_beat_sec() * 64)
            softcut.rate(i, 1.0 * self.samplerate / 48000 * clock.get_tempo() / self.bpm * 0.1)
        end
        clock.sync(math.random(1, 3))
        for _, i in ipairs(self.voices) do
            softcut.rate_slew_time(i, 0)
        end
    end)
end

function InfiniteBreaks:load_file(fname)
    if fname == nil then
        fname = self.files[math.random(#self.files)]
    end
    print("loading " .. fname)

    for buf, i in ipairs(self.voices) do
        softcut.enable(i, 1)
        softcut.buffer(i, buf)
        softcut.level(i, 0.1)
        softcut.loop(i, 1)
        softcut.loop_start(i, 260)
        softcut.loop_end(i, 261)
        softcut.position(i, 260)
        softcut.rate(i, 1.0)
        softcut.play(i, 1)
    end

    self.fname = fname
    self.beats = 4
    self.bpm = clock.get_tempo()
    local beats = fname:match("beats%d+")
    if beats ~= nil then
        beats = beats:match("%d+")
        if beats ~= nil then
            self.beats = tonumber(beats)
        end
    end
    local bpm = fname:match("bpm%d+")
    if bpm ~= nil then
        bpm = bpm:match("%d+")
        if bpm ~= nil then
            self.bpm = tonumber(bpm)
        end
    end
    self.ch, self.samples, self.samplerate = audio.file_info(self.fname)
    self.duration = self.samples / 48000.0
    self.start = 280 - self.duration
    if self.ch == 1 then
        softcut.buffer_read_mono(self.fname, 0, self.start, self.duration, 1, 1)
        softcut.buffer_read_mono(self.fname, 0, self.start, self.duration, 1, 2)
    else
        softcut.buffer_read_stereo(self.fname, 0, self.start, self.duration)
    end
    self.playing=true
    self.loaded_file=true
end


return InfiniteBreaks

