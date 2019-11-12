module app;
import grpc.server;
import grpc.server.builder;
import routeguide.route_guide;
import google.rpc.status;
import grpc.stream.server.reader;
import grpc.stream.server.writer;

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

        f.location.latitude = -1;
        f.location.longitude = 0;

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

        Point point;
        int point_count = 0;
        int feature_count = 0;
        float distance = 0.0;
        Point previous;
        import std.datetime.stopwatch;

        auto sw = StopWatch(AutoStart.yes);

        foreach(point; p.read()) {
            point_count++;
            if (GetFeatureName(point, _places) != "") {
                feature_count++;
            }
            if (point_count != 1) {
                distance += GetDistance(previous, point);
            }

            previous = point;
        }

        sw.stop();

        route.pointCount = point_count;
        route.featureCount = feature_count;
        route.distance = cast(int)distance;
        route.elapsedTime = cast(int)sw.peek.total!"seconds"();

        return t;
    }

    Status RouteChat(ref ServerReader!(RouteNote) rn, ServerWriter!(RouteNote) _rn) {
        Status t;

        _rn.start();

        foreach(msg; rn.read()) {
            foreach(n; receivedNotes) {
                if(n.location.latitude == msg.location.latitude &&
                        n.location.longitude == msg.location.longitude) {
                    _rn.write(n);
                }
            }

            receivedNotes ~= msg;
        }

        return t;
    }

    this() {
        readPlaces();
    }

    private {

        RouteNote[] receivedNotes; 
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

    ServerBuilder builder = new ServerBuilder();

    builder.port = 50051;

    auto server = builder.build();
    builder.register!(RouteGuideServer)();

    server.finish();

    server.run();
    
    server.wait();
}
