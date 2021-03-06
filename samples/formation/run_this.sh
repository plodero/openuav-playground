#!/bin/bash

source /simulation/inputs/parameters/swarm.sh
source /opt/ros/kinetic/setup.bash
source ~/catkin_ws/devel/setup.bash


apt-get update
apt-get install -y ros-kinetic-geodesy

## Previous clean-up
rm -rf /root/src/Firmware/Tools/sitl_gazebo/models/f450-tmp-*
rm -f /root/src/Firmware/posix-configs/SITL/init/lpe/f450-tmp-*
rm -f /root/src/Firmware/launch/posix_sitl_multi_tmp.launch

# world setup #
cp /simulation/inputs/world/empty.world /root/src/Firmware/Tools/sitl_gazebo/worlds/empty.world
cp /simulation/inputs/models/f450-1.sdf /root/src/Firmware/Tools/sitl_gazebo/models/f450-1/f450-1.sdf

rm -f /simulation/outputs/*.csv
rm -f /simulation/outputs/*.txt
echo "Setup..."
python /simulation/inputs/setup/testCreateUAVSwarm.py $num_uavs &> /dev/null &
sleep 20

echo "Launch UAVs"

for((i = 0;i<$num_uavs;i+=1))
do
    python /simulation/inputs/controllers/simple_Formation.py $i $num_uavs $FOLLOW_D_GAIN &> /simulation/outputs/patroLog$i.txt &
    sleep 6
done
echo "Launch Sequencer"
python /simulation/inputs/controllers/sequencer.py $num_uavs &> /simulation/outputs/sequencerLog.txt & 


roslaunch rosbridge_server rosbridge_websocket.launch ssl:=false &> /dev/null &
python /simulation/inputs/measures/measureInterRobotDistance.py $num_uavs 1 &> /dev/null &
rosrun web_video_server web_video_server _port:=80 _server_threads:=100 &> /dev/null &
tensorboard --logdir=/simulation/outputs/ --port=8008 &> /dev/null &
roslaunch opencv_apps general_contours.launch  image:=/uav_2_camera/image_raw_front debug_view:=false &> /dev/null &

echo "Measures..."
for((i=1;i<=$num_uavs;i+=1))
do
        /usr/bin/python -u /opt/ros/kinetic/bin/rostopic echo -p /mavros$i/local_position/odom > /simulation/outputs/uav$i.csv &
    done
    /usr/bin/python -u /opt/ros/kinetic/bin/rostopic echo -p /measure > /simulation/outputs/measure.csv &


    sleep $duration_seconds
    cat /simulation/outputs/measure.csv | awk -F',' '{sum+=$2; ++n} END { print sum/n }' > /simulation/outputs/average_measure.txt

