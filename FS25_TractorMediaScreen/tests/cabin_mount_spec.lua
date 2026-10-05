-- Transform/lifecycle regression tests. Real Valtra placement still needs a game test.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
local unpack = table.unpack or unpack
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local nodes, nextNode = {}, 100
local function node(parent, x, y, z, yaw)
    nextNode = nextNode + 1
    nodes[nextNode] = {parent = parent or 0, p = {x or 0, y or 0, z or 0}, yaw = yaw or 0}
    return nextNode
end
function getParent(id) return nodes[id] and nodes[id].parent or 0 end
function getTranslation(id) return unpack(nodes[id].p) end
function link(parent, child) nodes[child].parent = parent end
function setTranslation(id, x, y, z) nodes[id].p = {x, y, z} end
function setRotation(id, x, y, z) nodes[id].yaw = y end
function setDirection(id, x, y, z, ux, uy, uz) nodes[id].direction = {x, y, z, ux, uy, uz} end
function createTransformGroup() return node() end
function delete(id)
    local children = {}
    for child, data in pairs(nodes) do if data.parent == id then table.insert(children, child) end end
    for _, child in ipairs(children) do delete(child) end
    nodes[id] = nil
end
local function rotate(yaw, x, y, z)
    return math.cos(yaw)*x + math.sin(yaw)*z, y, -math.sin(yaw)*x + math.cos(yaw)*z
end
local function worldPose(id)
    if id == 0 then return 0, 0, 0, 0 end
    local value = nodes[id]
    local px, py, pz, yaw = worldPose(value.parent)
    local x, y, z = rotate(yaw, unpack(value.p))
    return px+x, py+y, pz+z, yaw+value.yaw
end
function localDirectionToLocal(from, to, x, y, z)
    local _, _, _, a = worldPose(from)
    local _, _, _, b = worldPose(to)
    return rotate(a-b, x, y, z)
end
function localToLocal(from, to, x, y, z)
    local fx, fy, fz, a = worldPose(from)
    local tx, ty, tz, b = worldPose(to)
    local rx, ry, rz = rotate(a, x, y, z)
    return rotate(-b, fx+rx-tx, fy+ry-ty, fz+rz-tz)
end
function getNumOfChildren(id)
    local total = 0
    for _, data in pairs(nodes) do if data.parent == id then total = total + 1 end end
    return total
end
function getChildAt(id, index)
    local children = {}
    for child, data in pairs(nodes) do if data.parent == id then table.insert(children, child) end end
    table.sort(children)
    return children[index+1]
end
local registered = {}
SpecializationUtil = {registerEventListener = function(_, event) registered[event] = true end}
Logging = {info = function() end, warning = function() end}
TractorMediaScreen = {modName = "FS25_TractorMediaScreen", modDirectory = mod .. "/"}
local released = 0
g_i3DManager = {releaseSharedI3DFile = function() released = released + 1 end}
local specKey = "spec_FS25_TractorMediaScreen.tractorMediaScreen"
dofile(mod .. "/scripts/TMSProfiles.lua")
dofile(mod .. "/scripts/vehicle/TMSVehicle.lua")
TMSVehicle.registerEventListeners({})
check(registered.onLoad and registered.onLoadFinished and registered.onDelete, "Mount waits for finalized camera data")

local function vehicle()
    local root = node(0, 12, 1, -17, .7)
    local cabin = node(root, 0, 2, -.3, .25)
    local cameraNode = node(cabin, 4, 8, -3, 1.2)
    local inside = {isInside = true, cameraNode = cameraNode, cameraPositionNode = cameraNode,
        rotateNode = cameraNode, origTransX = 0, origTransY = .8, origTransZ = 0}
    local outside = {isInside = false, cameraPositionNode = node(root, 0, 8, -8),
        origTransX = 0, origTransY = 8, origTransZ = -8}
    local result = {isClient = true, components = {{node = root}},
        spec_enterable = {cameras = {outside, inside}},
        configFileName = "data/vehicles/valtra/sSeries/sSeries.xml",
        configurations = {tmsMonitor = 2}, [specKey] = {}}
    function result:loadSubSharedI3DFile(_, _, _, callback, target, args)
        self.pending = function(id) callback(target, id, nil, args) end
        return 9
    end
    return result, inside, cabin, root
end
local function model()
    local wrapper = node()
    local monitor = node(wrapper)
    local display = node(monitor)
    return wrapper, monitor, display
end

local v, inside, cabin, root = vehicle()
local mount = TMSVehicle.resolveCabinMount(v, TMSProfiles.valtraS)
check(mount.parent == cabin and mount.cameraIndex == 2, "Uses indoor structural parent, not exterior or live camera")
check(near(mount.eye[1], 0) and near(mount.eye[2], .8) and near(mount.eye[3], 0),
    "Saved camera translation cannot move the monitor")
local mx, my, mz = localToLocal(cabin, root, unpack(mount.position))
local ex, ey, ez = localToLocal(cabin, root, unpack(mount.eye))
check(near(mx-ex, -.42) and near(my-ey, -.30) and near(mz-ez, .52),
    "Monitor sits right/below/forward of original eye even with a rotated cabin parent")
check(near(mount.direction[1], mount.eye[1]-mount.position[1])
    and near(mount.direction[2], mount.eye[2]-mount.position[2])
    and near(mount.direction[3], mount.eye[3]-mount.position[3]), "Display normal points towards original eye")

TMSVehicle.onLoad(v)
local wrapper, monitor, display = model()
v.pending(wrapper)
check(v[specKey].monitorNode == nil and nodes[wrapper] ~= nil, "Early I3D callback waits for camera finalization")
inside.origTransY = 1 -- Simulate the documented onPostLoad suspension Y correction.
TMSVehicle.onLoadFinished(v)
check(v[specKey].monitorNode == monitor and getParent(monitor) == cabin and nodes[wrapper] == nil,
    "Finished loading attaches once to cabin and releases wrapper")
check(near(nodes[monitor].p[2], .7), "Mount uses final suspension-adjusted eye height")
check(v[specKey].displayNode == display and nodes[monitor].direction ~= nil, "Display and facing are available")
local fixedX, fixedY, fixedZ = unpack(nodes[monitor].p)
nodes[inside.cameraPositionNode].p = {-4, -2, 5}
nodes[inside.cameraPositionNode].yaw = -2
TMSVehicle.onLoadFinished(v)
check(near(nodes[monitor].p[1], fixedX) and near(nodes[monitor].p[2], fixedY)
    and near(nodes[monitor].p[3], fixedZ), "Looking around cannot remount the monitor")

local late = vehicle()
TMSVehicle.onLoad(late)
TMSVehicle.onLoadFinished(late)
local lateWrapper, lateMonitor = model()
late.pending(lateWrapper)
check(late[specKey].monitorNode == lateMonitor, "Delayed I3D callback also mounts correctly")

local missing = vehicle()
missing.spec_enterable = nil
TMSVehicle.onLoad(missing)
local missingWrapper = model()
missing.pending(missingWrapper)
TMSVehicle.onLoadFinished(missing)
check(missing[specKey].monitorNode == nil and nodes[missingWrapper] == nil,
    "Missing cabin reference frees model instead of attaching at guessed exterior coordinates")

local unsafe, unsafeCamera = vehicle()
local worldParent = node()
unsafeCamera.cameraBaseParentNode = worldParent
check(TMSVehicle.resolveCabinMount(unsafe, TMSProfiles.valtraS) == nil, "World-space camera parent is never a vehicle mount")
unsafeCamera.cameraBaseParentNode = unsafeCamera.cameraNode
check(TMSVehicle.resolveCabinMount(unsafe, TMSProfiles.valtraS) == nil, "Moving camera parent is rejected")

local suspended, suspendedCamera, suspendedCabin, suspendedRoot = vehicle()
suspendedCamera.cameraBaseParentNode = suspendedCabin
local suspensionParent = node(suspendedRoot, 0, 4, 0)
link(suspensionParent, suspendedCamera.cameraPositionNode)
local stable = TMSVehicle.resolveCabinMount(suspended, TMSProfiles.valtraS)
check(stable.parent == suspendedCabin and near(stable.eye[2], .8),
    "Camera suspension toggle cannot change the structural mount reference")

local pivotVehicle, pivotCamera, pivotCabin = vehicle()
local pivot = node(pivotCabin, .1, .2, .3, -math.pi/2)
link(pivot, pivotCamera.cameraPositionNode)
pivotCamera.rotateNode = pivot
pivotCamera.origTransX, pivotCamera.origTransY, pivotCamera.origTransZ = 0, .8, .2
pivotCamera.origRotX, pivotCamera.origRotY, pivotCamera.origRotZ = 0, math.pi/2, 0
local neutral = TMSVehicle.resolveCabinMount(pivotVehicle, TMSProfiles.valtraS)
check(neutral.parent == pivotCabin and near(neutral.eye[1], .3)
    and near(neutral.eye[2], 1) and near(neutral.eye[3], .3), "Separate look pivot is reconstructed at original rotation")
check(near(nodes[pivot].yaw, -math.pi/2), "Neutral reconstruction does not change player's camera")

local deleted = vehicle()
TMSVehicle.onLoad(deleted)
local deletedWrapper = model()
deleted.pending(deletedWrapper)
TMSVehicle.onDelete(deleted)
check(nodes[deletedWrapper] == nil and deleted[specKey].pendingI3d == nil, "Delete frees waiting I3D")
TMSVehicle.onDelete(deleted)
check(released == 1, "Shared load request released exactly once")
local tooLateWrapper, tooLateMonitor = model()
deleted.pending(tooLateWrapper)
check(nodes[tooLateWrapper] == nil and nodes[tooLateMonitor] == nil, "Callback after deletion is discarded")

g_dedicatedServer = {}
local server = vehicle()
TMSVehicle.onLoad(server)
TMSVehicle.onLoadFinished(server)
check(server.pending == nil and server[specKey].mount == nil, "Dedicated server does not load or resolve visual mount")
g_dedicatedServer = nil
print(string.format("Cabin mount: %d checks passed (%s)", count, _VERSION))
