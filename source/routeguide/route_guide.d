// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: route_guide.proto

module routeguide.route_guide;

import google.protobuf;
import google.rpc.status;
import grpc.stream.server.writer;
import grpc.stream.server.reader;


enum protocVersion = 3007000;

struct Point
{
    @Proto(1) int latitude = protoDefaultValue!int;
    @Proto(2) int longitude = protoDefaultValue!int;
}

struct Rectangle
{
    @Proto(1) Point lo = protoDefaultValue!Point;
    @Proto(2) Point hi = protoDefaultValue!Point;
}

struct Feature
{
    @Proto(1) string name = protoDefaultValue!string;
    @Proto(2) Point location = protoDefaultValue!Point;
}

struct RouteNote
{
    @Proto(1) Point location = protoDefaultValue!Point;
    @Proto(2) string message = protoDefaultValue!string;
}

struct RouteSummary
{
    @Proto(1) int pointCount = protoDefaultValue!int;
    @Proto(2) int featureCount = protoDefaultValue!int;
    @Proto(3) int distance = protoDefaultValue!int;
    @Proto(4) int elapsedTime = protoDefaultValue!int;
}

interface RouteGuide
{
    @RPC("/routeguide.RouteGuide/GetFeature")
    Status GetFeature(Point, ref Feature);

    @RPC("/routeguide.RouteGuide/ListFeatures")
    @ServerStreaming
    Status ListFeatures(Rectangle, ServerWriter!(Feature));

    @RPC("/routeguide.RouteGuide/RecordRoute")
    @ClientStreaming
    Status RecordRoute(ServerReader!(Point), ref RouteSummary);

    @RPC("/routeguide.RouteGuide/RouteChat")
    @ClientStreaming
    @ServerStreaming
    Status RouteChat(ref ServerReader!(RouteNote), ServerWriter!(RouteNote));

}