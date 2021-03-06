// Copyright 2017 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// node key constraints are available only in enterprise edition
// CREATE CONSTRAINT ON (u:WindowsADUser) ASSERT (u.sketch_id, u.username) IS NODE KEY;
// CREATE CONSTRAINT ON (u:WindowsLocalUser) ASSERT (u.sketch_id, u.hostname, u.username) IS NODE KEY;
// CREATE CONSTRAINT ON (m:WindowsMachine) ASSERT (m.sketch_id, m.hostname) IS NODE KEY;
// CREATE CONSTRAINT ON (s:WindowsService) ASSERT (s.sketch_id, s.service_name) IS NODE KEY;
// CREATE CONSTRAINT ON (p:WindowsServiceImagePath) ASSERT (p.sketch_id, p.image_path) IS NODE KEY;
// CREATE CONSTRAINT ON ()-[r:ACCESS]-() ASSERT exists(r.sketch_id);
// CREATE CONSTRAINT ON ()-[r:START]-() ASSERT exists(r.sketch_id);
// CREATE CONSTRAINT ON ()-[r:HAS]-() ASSERT exists(r.sketch_id);

UNWIND {win_logins} AS line
WITH line
WHERE line.src <> line.dst

  MERGE (src:WindowsMachine { hostname: line.src, sketch_id: {sketch_id} })
  MERGE (dst:WindowsMachine { hostname: line.dst, sketch_id: {sketch_id} })
  SET src.es_index_name = coalesce(src.es_index_name, line.es_index_name),
      dst.es_index_name = line.es_index_name

  MERGE (src)-[r:ACCESS { method: line.method, username: line.user }]->(dst)
  ON CREATE SET r.es_index_name = line.es_index_name,
                r.es_query = line.es_query,
                r.sketch_id = {sketch_id},
                r.timestamps = [line.timestamp],
                r.timestamps_incomplete = False
  ON MATCH SET r.timestamps =
    CASE
      WHEN size(r.timestamps) < {max_timestamps} AND NOT line.timestamp IN (r.timestamps) THEN
        r.timestamps + [line.timestamp]
      ELSE
        r.timestamps
    END,
    r.timestamps_incomplete = size(r.timestamps) >= {max_timestamps}
;

UNWIND {win_logins} AS line
WITH line
WHERE line.src = line.dst

  MERGE (user:WindowsADUser { username: line.user, sketch_id: {sketch_id} })
  MERGE (dst:WindowsMachine { hostname: line.dst, sketch_id: {sketch_id} })
  SET dst.es_index_name = line.es_index_name

  MERGE (user)-[r:ACCESS {method: line.method, username: line.user}]->(dst)
  ON CREATE SET r.es_index_name = line.es_index_name,
                r.es_query = line.es_query,
                r.sketch_id = {sketch_id},
                r.timestamps = [line.timestamp],
                r.timestamps_incomplete = False
  ON MATCH SET r.timestamps =
    CASE
      WHEN size(r.timestamps) < {max_timestamps} AND NOT line.timestamp IN (r.timestamps) THEN
        r.timestamps + [line.timestamp]
      ELSE
        r.timestamps
    END,
    r.timestamps_incomplete = size(r.timestamps) >= {max_timestamps}
;

UNWIND {win_services} AS line
WITH line

  MERGE (src:WindowsMachine { hostname: line.src, sketch_id: {sketch_id} })
  MERGE (service:WindowsService { service_name: line.svc_name, sketch_id: {sketch_id} })
  MERGE (image_path:WindowsServiceImagePath { image_path: line.image_path, sketch_id: {sketch_id} })
  SET src.es_index_name = coalesce(src.es_index_name, line.es_index_name),
      image_path.image_path_short = line.image_path_short

  MERGE (service)-[r:START {start_type: line.start_type}]->(src)
  ON CREATE SET r.es_index_name = line.es_index_name,
      r.es_query = line.es_query,
      r.sketch_id = {sketch_id},
      r.timestamps = [line.timestamp],
      r.timestamps_incomplete = False
  ON MATCH SET r.timestamps =
    CASE
      WHEN size(r.timestamps) < {max_timestamps} AND NOT line.timestamp IN (r.timestamps) THEN
        r.timestamps + [line.timestamp]
      ELSE
        r.timestamps
    END,
    r.timestamps_incomplete = size(r.timestamps) >= {max_timestamps}

  MERGE (service)-[h:HAS]->(image_path)
  SET h.es_index_name = line.es_index_name,
      h.es_query = line.es_query,
      h.sketch_id = {sketch_id}
;
