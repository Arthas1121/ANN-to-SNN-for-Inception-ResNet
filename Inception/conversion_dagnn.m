% �������ݼ���ģ��·��
modelPath='C:\Program Files\MATLAB\R2016b\matconvnet-1.0-beta25\matconvnet-1.0-beta25\data\cifar-inception-v4-4\net-deployed.mat';
imdbPath= 'imdb_whiten.mat';

% �������ݼ���һ��ҪҪ���ȼ�����ݼ��Բ���
% imdb=load(imdbPath);
trainSet=find(imdb.images.set==1);
testSet=find(imdb.images.set==3);
num_examples=60000;

% ���� CNN ѵ��ģ�ͣ������ģ�ͱ����� deployed ֮���
% net=load(modelPath);
% net=dagnn.DagNN.loadobj(net);


% -------------------------------------------------------------------------
%                                                         �����㼶��ϵ����ͼ
% -------------------------------------------------------------------------

link=zeros(numel(net.layers),2); % �洢 layers ��ţ��ⲿ�ֲ��ı�����ṹ

link(1,2)=1; % ��һ��ֱ�Ӹ�ֵ������ l = 0.

for l=2:numel(net.layers) % �� 2 ��ʼ 
	
	% ��������л����ҵ���һ�� conv ����� concat �㣬concat ����
	if isa(net.layers(l).block,'dagnn.Conv')
		ll=l;
		while true
			i=net.layers(ll).inputIndexes-1;
			if isa(net.layers(i).block,'dagnn.Concat') || isa(net.layers(i).block,'dagnn.Conv')
				link(l,1)=i;
				break;
			end
			ll=i;
		end
		link(l,2)=l; % ������� concat ������ conv �������Ϊ����

	% ���ڼ��� max pooling �������� reduction block �ĵ���֧·��
	% stem ��Ҳ���� max pooling�������ٽ�����㲻���� concat
	elseif isa(net.layers(l).block,'dagnn.Pooling') && strcmp(net.layers(l).block.method,'max')
		i=net.layers(l).inputIndexes-1;
		if isa(net.layers(i).block,'dagnn.Concat')
			link(l,1)=i;
        elseif isa(net.layers(i-1).block,'dagnn.Conv')
            link(l,1)=i-1;
		end
		
	elseif isa(net.layers(l).block,'dagnn.Concat')
		for i=net.layers(l).inputIndexes-1
			% ���� concat �� conv ������֮��ֻ�� ReLU, û�� Pooling���������Ի��ݣ��Ҿ�����������
			% �������ֱ��ʹ�ò����ݼ����ݣ�ֻ��������ȷ����Խ�� concat.
			for j=i:-1:i-1 
				if isa(net.layers(j).block,'dagnn.Conv') || isa(net.layers(j).block,'dagnn.Pooling')
					link(j,2)=l;
                end
			end
		end
	end
end


% -------------------------------------------------------------------------
%                                 ǰ���䣬��¼����ֵ����¼ link ��ز㼤��ֵ
% -------------------------------------------------------------------------
for l=nonzeros(unique(link))'
	net.vars(net.layers(l).outputIndexes).precious=true;
end

% �鿴���о����� max activation
% for l=1:numel(net.layers)
%     if isa(net.layers(l).block,'dagnn.Conv')
%         net.vars(net.layers(l).outputIndexes).precious=true;
%     end
% end

% ��ʼǰ���䣬ǰ����ǰ��Ҫ�� DagNN model �ṹ������κ��Զ����Ԫ��
batchSize=100;
epochs=ceil(num_examples/batchSize);

% output ������ֵ����ת������ռ�ù����ڴ�
output=cell(1,numel(net.vars));

net.mode='test';
for epoch=61:70

	batchStart=(epoch-1)*batchSize+1;
	batchEnd=min(epoch*batchSize,num_examples);
	batch=testSet(batchStart:batchEnd);

	im=imdb.images.data(:,:,:,batch);
	label=imdb.images.labels(1,batch);
    inputs={'input',im};
	net.eval(inputs);

    % l �ǲ������output �Ǳ���������Ҳ����ֱ�ӱ�������
	for l=nonzeros(unique(link))'
		output{net.layers(l).outputIndexes}=cat(4,output{net.layers(l).outputIndexes},...
												net.vars(net.layers(l).outputIndexes).value);
    end
    
    % �鿴���о����� max_activation
%     for l=1:numel(net.layers)
%         if isa(net.layers(l).block,'dagnn.Conv')
%             output{net.layers(l).outputIndexes}=cat(4,output{net.layers(l).outputIndexes},...
%                                                     net.vars(net.layers(l).outputIndexes).value);
%         end
%     end

    fprintf('%d epoch forward finised.\n',epoch);
end

% �������������ظ�ֵ net.vars
for i=1:numel(net.vars)
	net.vars(i).value=output{i};
end
clear output;

snn=parse_dagnn(net,link,99.99); % �ǵøĻ�99.99

opts.dt 			= 0.001;
opts.duration		= 2.500;
opts.report_every	= 0.010; % �˴��иĶ�
opts.threshold		=   1.0;
opts.batch 			=56001:57000;

[performance,stats]=dagnn2snn(snn,imdb,opts);
