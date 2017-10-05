

classdef zoidberg

	properties
		path_to_neuron_model_db
		path_to_stg_model_db
	end

	properties (Access = protected)
		conductance_multipliers = [1000 25 20 100 50 250 .1 .1];
		n_neurons = 1679616;
		zoidberg_folder
	end

	methods 

		function self = zoidberg()

			% check for paths to model_db
			self.zoidberg_folder = fileparts(which(mfilename));

			% search this for paths files
			if exist(joinPath(self.zoidberg_folder,'paths.zoidberg'),'file')
				load(joinPath(self.zoidberg_folder,'paths.zoidberg'),'-mat')
				self.path_to_neuron_model_db = path_to_neuron_model_db;
			else
				warning('Path to neuron model DB unknown. Configure before using.')
			end
		end

		function self =  set.path_to_neuron_model_db(self,value)
			% check that this exists, and is a folder 
			assert(isdir(value),'Argument should be a directory')
			self.path_to_neuron_model_db = value;
			path_to_neuron_model_db = value;
			try
				save(joinPath(self.zoidberg_folder,'paths.zoidberg'),'path_to_neuron_model_db','-append')
			catch
				save(joinPath(self.zoidberg_folder,'paths.zoidberg'),'path_to_neuron_model_db')
			end

		end

		function [G] = findNeurons(self,neuron_type,varargin)


			% options and defaults
			options.min_burst_period = 1.5;
			options.max_burst_period = 2.5;


			% validate and accept options
			if iseven(length(varargin))
				for ii = 1:2:length(varargin)-1
				temp = varargin{ii};
			    if ischar(temp)
			    	if ~any(find(strcmp(temp,fieldnames(options))))
			    		disp(['Unknown option: ' temp])
			    		disp('The allowed options are:')
			    		disp(fieldnames(options))
			    		error('UNKNOWN OPTION')
			    	else
			    		options = setfield(options,temp,varargin{ii+1});
			    	end
			    end
			end
			elseif isstruct(varargin{1})
				% should be OK...
				options = varargin{1};
			else
				error('Inputs need to be name value pairs')
			end

			filename = joinPath(self.path_to_neuron_model_db,'spontaneous_type_periodorpotential_minmaxnumber.dat');

			fid = fopen(filename);
			l = self.n_neurons;
			model_id = zeros(l,1);
			activity_type = zeros(l,1);
			burst_period = NaN(l,1);

			C = textscan(fid,'%f %u %f %u');
			fclose(fid);
			model_id = C{1};
			activity_type = C{2};
			burst_period = C{3};
			nmaxmin = C{4};


			switch neuron_type
			case 'burster'
				activity_filter = 2;
			case 'silent'
				activity_filter = 0;
			case 'spiker'
				activity_filter = 1;
			case 'irregular'
				activity_filter = 3;
			otherwise
				error('Unknown neuron type. Should be one of: {"burster", "silent", "spiker", "irregular"}')
			end

			% filter based on activity 
			filter_idx = activity_type == activity_filter & burst_period > options.min_burst_period & burst_period < options.max_burst_period;
			these_models = model_id(filter_idx);
			these_burst_periods = burst_period(filter_idx);
			nmaxmin = nmaxmin(filter_idx);
			

			disp([mat2str(length(these_models)) ' neurons found'])

			G = self.model_id_2_cond(these_models);


		end % end findNeurons

		function g = model_id_2_cond(self,model_id)
			% look up conductancelevels.dat to get the levels
			filename = joinPath(self.path_to_neuron_model_db,'conductancelevels.dat');
			fid = fopen(filename);
			C = textscan(fid,'%f %u %u %u %u %u %u %u %u');
			fclose(fid);
			all_g = NaN(8,self.n_neurons);
			for i = 1:8
				all_g(i,:) = C{i+1};
			end
			assert(length(C{2}) == self.n_neurons, 'Unexpected number of neurons in database')

			g = all_g(:,model_id);

			for i = 1:size(g,2)
				g(:,i) = g(:,i).*self.conductance_multipliers(:);
			end
		end


	end % end methods

end % end classdef 




