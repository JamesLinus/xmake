--!The Automatic Cross-platform Build Tool
-- 
-- XMake is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 2.1 of the License, or
-- (at your option) any later version.
-- 
-- XMake is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public License
-- along with XMake; 
-- If not, see <a href="http://www.gnu.org/licenses/"> http://www.gnu.org/licenses/</a>
-- 
-- Copyright (C) 2015 - 2016, ruki All rights reserved.
--
-- @author      ruki
-- @file        io.lua
--

-- define module
local io    = io or {}
local _file = _file or {}

-- load modules
local path  = require("base/path")
local utils = require("base/utils")

-- save original open
io._open = io._open or io.open

-- read file
function _file.read(self, ...)

    -- check
    assert(self._FILE)
    
    -- read it
    return self._FILE:read(...)
end

-- write file
function _file.write(self, ...)

    -- check
    assert(self._FILE)
    
    -- write it
    return self._FILE:write(...)
end

-- print file
function _file.print(self, ...)

    -- check
    assert(self._FILE)
    
    -- print it
    return self._FILE:write(string.format(...) .. "\n")
end

-- printf file
function _file.printf(self, ...)

    -- check
    assert(self._FILE)
    
    -- printf it
    return self._FILE:write(string.format(...))
end

-- get lines
function _file.lines(self)

    -- check
    assert(self._FILE)
    
    -- get it
    return self._FILE:lines()
end

-- close file
function _file.close(self)

    -- check
    assert(self._FILE)
    
    -- close it
    return self._FILE:close()
end

-- save object with the level
function _file._save(self, object, level)
 
    -- save string
    if type(object) == "string" then  
        self:printf("%q", object)
    -- save boolean
    elseif type(object) == "boolean" then  
        self:write(tostring(object))  
    -- save number 
    elseif type(object) == "number" then  
        self:write(object)  
    -- save table
    elseif type(object) == "table" then  

        -- save head
        self:write("\n")  
        for l = 1, level do
            self:write("    ")
        end
        self:write("{\n")

        -- save body
        local i = 0
        for k, v in pairs(object) do  

            -- save spaces and separator
            for l = 1, level do
                self:write("    ")
            end

            self:write(utils.ifelse(i == 0, "    ", ",   "))
            
            -- save key
            if type(k) == "string" then
                self:write(string.format("[%q]", k), " = ")  
            end

            -- save value
            if not self:_save(v, level + 1) then 
                return false
            end

            -- save newline
            self:write("\n")
            i = i + 1
        end  

        -- save tail
        for l = 1, level do
            self:write("    ")
        end
        self:write("}\n")  
    else  
        -- error
        utils.error("invalid object type: %s", type(object))
        return false
    end  

    -- ok
    return true
end

-- save object
function _file.save(self, object)
   
    -- save it
    return self:_save(object, 0)
end

-- load object
function _file.load(self)

    -- check
    assert(self)

    -- load data
    local result = nil
    local errors = nil
    local data = self:read("*all")
    if data and type(data) == "string" then

        -- load script
        local script, errs = loadstring("return " .. data)
        if script then
            
            -- load object
            local ok, object = pcall(script)
            if ok and object then
                result = object
            elseif object then
                -- error
                errors = object
            else
                -- error
                errors = string.format("load %s failed!", filepath)
            end
        -- errors
        else errors = errs end
    end

    -- ok?
    return result, errors
end

-- read all data from file 
function io.readall(filepath)

    -- open file
    local file = io.open(filepath, "r")
    if not file then
        -- error
        return nil, string.format("open %s failed!", filepath)
    end

    -- read all
    local data = file:read("*all")

    -- exit file
    file:close()

    -- ok?
    return data
end

-- write all data to file 
function io.writall(filepath, data)

    -- open file
    local file = io.open(filepath, "w")
    if not file then
        -- error
        return false, string.format("open %s failed!", filepath)
    end

    -- write all
    file:write(data)

    -- exit file
    file:close()

    -- ok?
    return true
end

-- replace the original open interface
function io.open(filepath, mode)

    -- check
    assert(filepath)

    -- write file?
    if mode == "w" then

        -- get the file directory
        local dir = path.directory(filepath)

        -- ensure the file directory 
        if not os.isdir(dir) then
            os.mkdir(dir) 
        end
    end

    -- init file instance
    local file = {}
    for k, v in pairs(_file) do
        if type(v) == "function" then
            file[k] = v
        end
    end

    -- open it
    local handle, errors = io._open(path.translate(filepath), mode)
    if not handle then
        return nil, errors
    end

    -- save file handle
    file._FILE = handle

    -- ok?
    return file, errors
end

-- save object the the given filepath
function io.save(filepath, object)

    -- check 
    assert(filepath and object)

    -- ensure directory
    local dir = path.directory(filepath)
    if not os.isdir(dir) then
        os.mkdir(dir)
    end
    
    -- open the file
    local file = io.open(filepath, "w")
    if not file then
        -- error
        return false, string.format("open %s failed!", filepath)
    end

    -- save object to file
    if not file:save(object) then
        -- error 
        file:close()
        return false, string.format("save %s failed!", filepath)
    end

    -- close file
    file:close()
   
    -- ok
    return true
end
 
-- load object from the given file
function io.load(filepath)

    -- check
    assert(filepath)

    -- open the file
    local file = io.open(filepath, "r")
    if not file then
        -- error
        return nil, string.format("open %s failed!", filepath)
    end

    -- load object
    local result, errors = file:load()

    -- close file
    file:close()

    -- ok?
    return result, errors
end

-- gsub the given file and return replaced data
function io.gsub(filepath, pattern, replace)

    -- read all data from file
    local data, errors = io.readall(filepath)
    if not data then return nil, 0, errors end

    -- replace it
    local count = 0
    if type(data) == "string" then
        data, count = data:gsub(pattern, replace)
    else
        return nil, 0, string.format("data is not string!")
    end

    -- replace ok?
    if count ~= 0 then
        -- write all data to file
        local ok, errors = io.writall(filepath, data) 
        if not ok then return nil, 0, errors end
    end

    -- ok
    return data, count
end

-- cat the given file 
function io.cat(filepath, linecount)

    -- open file
    local file = io.open(filepath, "r")
    if file then

        -- show file
        local count = 1
        for line in file:lines() do

            -- show line
            print(line)

            -- end?
            if linecount and count >= linecount then
                break
            end

            -- update the line count
            count = count + 1
        end 

        -- exit file
        file:close() 
    end
end

-- tail the given file 
function io.tail(filepath, linecount)

    -- open file
    local file = io.open(filepath, "r")
    if file then

        -- read lines
        local lines = {}
        for line in file:lines() do
            table.insert(lines, line)
        end

        -- tail lines
        local tails = {}
        if #lines ~= 0 then
            local count = 1
            for index = #lines, 1, -1 do

                -- show line
                table.insert(tails, lines[index])

                -- end?
                if linecount and count >= linecount then
                    break
                end

                -- update the line count
                count = count + 1
            end
        end

        -- show tails
        if #tails ~= 0 then
            for index = #tails, 1, -1 do

                -- show tail
                print(tails[index])

            end
        end

        -- exit file
        file:close() 
    end
end

-- return module
return io
