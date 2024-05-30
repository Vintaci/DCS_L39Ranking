Utils = {}
do
    function Utils.messageToAll(text,displayTime,clearview)
        local displayTime = displayTime or 5
        local clearview = clearview or false
        trigger.action.outText(text, displayTime, clearview)
    end

    function Utils.getTbaleSize(table)
        local size = 0
        for _ in pairs(table) do size = size + 1 end
        return size
    end

    function Utils.vecTranslate(vec3,rad,distance)
        local point = {x = vec3.x,y = vec3.z or vec3.y,}
        
        if distance == 0 then return point end
    
        local radian = math.rad(rad)
    
        point.x = point.x + distance * math.cos(radian)
        point.y = point.y + distance * math.sin(radian)
        return point
    end

    function Utils.getDirection(vec3_1,vec3_2)
        local p1 = mist.utils.makeVec3GL(vec3_1)
        local p2 = mist.utils.makeVec3GL(vec3_2)
        local dir = mist.utils.getDir(mist.vec.sub(p1, p2))

        return dir
    end
end