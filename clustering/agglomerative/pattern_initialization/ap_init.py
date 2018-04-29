import numpy as np
import logging
from time import time
log = logging.getLogger(__name__)

from clustering.agglomerative.utils.a_ward_cluster_structure import AWardClusterStructure


class APInit:
    _MAX_LOOPS = 500

    def __init__(self, data, threshold=1):
        self._data = data
        self.threshold = threshold
        self._index = np.arange(len(data), dtype=int)[None].T
        self._origin = self._calculate_origin()
        self._completed = False
        self._cluster_structure = self._create_cluster_structure()

    def _create_cluster_structure(self):
        return AWardClusterStructure(self._data)

    def _calculate_origin(self):
        return np.mean(self._data, axis=0)

    def _furthest_point_relative_index(self, current_data):
        dist_point_to_origin = np.apply_along_axis(
            func1d=lambda point: self._cluster_structure.dist_point_to_point(point, self._origin),
            axis=1, arr=current_data)
        return dist_point_to_origin.argmax()

    @property
    def cluster_structure(self):
        if not self._completed:
            raise APInit.AccessToUnavailableResult("Can't return clusters because the algorithm must be "
                                                   "executed first. Please, use __call__ to run algorithm.")
        return self._cluster_structure

    def _cluster(self, points_indices):
        return self._cluster_structure.release_new_cluster(points_indices)

    def __call__(self):
        start = time()
        log.info("starting anomalous pattern initialization")
        current_data = self._data
        current_index = self._index
        while len(current_index) > 0:
            log.info("current data size: {}".format(len(current_index)))
            # step 2
            tentative_centroid_relative_index = self._furthest_point_relative_index(current_data)
            tentative_centroid_index = current_index[tentative_centroid_relative_index]

            anomalous_cluster = self._cluster(tentative_centroid_index)

            anomaly = np.full(shape=current_index.shape, fill_value=False, dtype=bool)
            anomaly[tentative_centroid_relative_index] = True

            for loop_control in range(APInit._MAX_LOOPS):
                dist_point_to_origin = np.apply_along_axis(
                    func1d=lambda point: self._cluster_structure.dist_point_to_point(point,
                                                                                     self._origin, anomalous_cluster),
                    axis=1, arr=current_data)

                dist_point_to_anomalous_centroid = np.apply_along_axis(
                    func1d=lambda point: self._cluster_structure.dist_point_to_cluster(point, anomalous_cluster),
                    axis=1, arr=current_data)

                anomaly = dist_point_to_origin >= dist_point_to_anomalous_centroid
                anomalous_points_indices = current_index[anomaly].flatten()
                new_anomalous_cluster = self._cluster(anomalous_points_indices)  # step 3 and 4,5 inside update
                # TODO here we have to compare a lot of indices, what about performance?
                if new_anomalous_cluster == anomalous_cluster:
                    break
                anomalous_cluster = new_anomalous_cluster
            if anomalous_cluster.power >= self.threshold:
                self._cluster_structure.add_cluster(anomalous_cluster)
            current_data = current_data[~anomaly]
            current_index = current_index[~anomaly]
        self._completed = True
        log.info("anomalous pattern initialization completed in {:5.2f} sec.".format(time() - start))
        return self._cluster_structure.current_labels()

    class AccessToUnavailableResult(BaseException):
        pass
