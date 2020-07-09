module app;
import grpc.server;
import grpc.server.builder;
import routeguide.route_guide;
import google.rpc.status;
import grpc.stream.server.reader;
import grpc.stream.server.writer;
import grpc.logger;

float ConvertToRadians(float num) {
    return num * 3.1415926 /180;
}

float GetDistance(const Point start, const Point end) {
    import std.math;
    const float kCoordFactor = 10000000.0;
    float lat_1 = start.latitude / kCoordFactor;
    float lat_2 = end.latitude / kCoordFactor;
    float lon_1 = start.longitude / kCoordFactor;
    float lon_2 = end.longitude / kCoordFactor;
    float lat_rad_1 = ConvertToRadians(lat_1);
    float lat_rad_2 = ConvertToRadians(lat_2);
    float delta_lat_rad = ConvertToRadians(lat_2-lat_1);
    float delta_lon_rad = ConvertToRadians(lon_2-lon_1);
    float a = pow(sin(delta_lat_rad/2), 2) + cos(lat_rad_1) * cos(lat_rad_2) *
            pow(sin(delta_lon_rad/2), 2);
    float c = 2 * atan2(sqrt(a), sqrt(1-a));
    int R = 6371000; // metres

    return R * c;
}


class RouteGuideServer : RouteGuide {
    Status GetFeature(Point p, ref Feature f) {
        Status t;

        foreach(place; _places) {
            if(p.longitude == place.location.longitude && p.latitude == place.location.latitude) {
                f.name = place.name;
                f.location.latitude = p.latitude;
                f.location.longitude = p.longitude;
                break;
            }
        }

        return t;
    }

    Status ListFeatures(Rectangle r, ServerWriter!(Feature) out_) {
        Status t;

        import std.algorithm.comparison;
        auto lo = r.lo;
        auto hi = r.hi;
        long left = min(lo.longitude, hi.longitude);
        long right = max(lo.longitude, hi.longitude);
        long top = max(lo.latitude, hi.latitude);
        long bottom = min(lo.latitude, hi.latitude);

        writeln("ListFeatures");

        foreach(place; _places) {
            if(place.location.longitude >= left &&
               place.location.longitude <= right &&
               place.location.latitude >= bottom &&
               place.location.latitude <= top) {

                Feature f;
                f.location.longitude = cast(int)place.location.longitude;
                f.location.latitude = cast(int)place.location.latitude;
                f.name = place.name;

                out_.write(f);
            }
        }

        return t;
    }

    Status RecordRoute(ServerReader!(Point) p, ref RouteSummary route) {
        Status t;

        int point_count = 0;
        int feature_count = 0;
        float distance = 0.0;
        Point previous;
        import std.datetime;

        writeln("RecordRoute");
        auto before = Clock.currTime();

        Point point = p.readOne();

        while (point !is Point.init) {
            point_count++;
            if (GetFeatureName(point, _places) != "") {
                feature_count++;
            }
            if (point_count != 1) {
                distance += GetDistance(previous, point);
            }

            previous = point;
            point = p.readOne();
        }

        auto timeElapsed = Clock.currTime() - before;

        route.pointCount = point_count;
        route.featureCount = feature_count;
        route.distance = cast(int)distance;
        timeElapsed.split!"seconds"(route.elapsedTime);

        return t;
    }

    Status RouteChat(ServerReader!(RouteNote) rn, ServerWriter!(RouteNote) _rn) {
        Status t;

        writeln("RouteChat");
        _rn.start();

        RouteNote[] receivedNotes; 
        import core.time;
        RouteNote msg = rn.readOne();
        while(msg !is RouteNote.init) {
            writeln("received note: ", msg);
            foreach(n; receivedNotes) {
                if(n.location.latitude == msg.location.latitude &&
                        n.location.longitude == msg.location.longitude) {
                    writeln("found matching note: ", n);
                    _rn.write(n);
                }
            }

            receivedNotes ~= msg;
            msg = rn.readOne();
        }

        return t;
    }

    this() {
        readPlaces();
    }

    private {

        string GetFeatureName(Point point, Feature[] list) {
            foreach(feature; list) {
                if(feature.location.latitude == point.latitude && feature.location.longitude == point.longitude) {
                    return feature.name;
                }
            }
            return "";
        }

        Feature[] _places;
        void readPlaces() {
            import std.file;
            auto json = readText("route_guide_db.json");

            import std.json;
            import google.protobuf.json_decoding;

            _places = fromJSONValue!(Feature[])(parseJSON(json));

            writeln("Read ", _places.length, " places");
        }

    }
}

import std.stdio;
void main() {

    import grpc.logger;
    debug gLogger.minVerbosity = Verbosity.Debug; 

    ServerBuilder builder = new ServerBuilder();

    builder.port = 50051;

    auto server = builder.build();
    builder.register!(RouteGuideServer)();

    server.run();
    
    server.wait();
}
